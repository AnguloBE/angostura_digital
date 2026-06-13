const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated, onDocumentUpdated, onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
setGlobalOptions({maxInstances: 10});

const db = getFirestore();
const {FieldValue} = require("firebase-admin/firestore");

function redondearMonto(n) {
  return Math.round(n * 100) / 100;
}

function debeReiniciarPeriodo(inicio, periodo) {
  if (!inicio || !inicio.toDate) return false;
  const dias = Math.floor((Date.now() - inicio.toDate().getTime()) / 86400000);
  if (periodo === "semanal") return dias >= 7;
  if (periodo === "quincenal") return dias >= 15;
  return dias >= 30;
}

async function ajustarComisionAcumulada(negocioId, delta, {reiniciarSiVencio = true} = {}) {
  if (!delta) return;

  const ref = db.collection("negocios").doc(negocioId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const data = snap.data();
    const periodo = data.comision_periodo || "mensual";
    const inicio = data.comision_periodo_inicio;
    const actual = Number(data.comision_acumulada || 0);

    if (delta > 0 && reiniciarSiVencio && debeReiniciarPeriodo(inicio, periodo)) {
      tx.update(ref, {
        comision_acumulada: redondearMonto(delta),
        comision_periodo_inicio: FieldValue.serverTimestamp(),
      });
      return;
    }

    const nueva = redondearMonto(Math.max(0, actual + delta));
    const updates = {comision_acumulada: nueva};
    if (delta > 0 && !inicio) {
      updates.comision_periodo_inicio = FieldValue.serverTimestamp();
    }
    tx.update(ref, updates);
  });
}

async function acumularComisionDesdePedido(negocioId, pedido) {
  const monto = Number(pedido.comision_app || 0);
  if (monto <= 0 || pedido.estado === "Cancelado") return;
  await ajustarComisionAcumulada(negocioId, monto);
}

async function revertirComisionDesdePedido(negocioId, pedidoId, pedido) {
  if (pedido.comision_revertida) return;
  const monto = Number(pedido.comision_app || 0);
  if (monto <= 0 || !pedido.comision_contabilizada) return;

  await ajustarComisionAcumulada(negocioId, -monto, {reiniciarSiVencio: false});
  await db.collection("pedidos").doc(pedidoId).update({comision_revertida: true});
}

async function procesarPagoComision(negocioId, pagoRef, monto) {
  const ref = db.collection("negocios").doc(negocioId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    const actual = Number(snap.data().comision_acumulada || 0);
    const nuevoSaldo = redondearMonto(Math.max(0, actual - monto));

    tx.update(ref, {
      comision_acumulada: nuevoSaldo,
      comision_ultimo_pago_monto: monto,
      comision_ultimo_pago_fecha: FieldValue.serverTimestamp(),
    });
    tx.update(pagoRef, {
      saldo_antes: actual,
      saldo_despues: nuevoSaldo,
      fecha: FieldValue.serverTimestamp(),
      procesado: true,
    });
  });
}

async function obtenerTokenUsuario(uid) {
  if (!uid) return null;
  const doc = await db.collection("usuarios").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data()?.fcm_token || null;
}

async function enviarPush(token, titulo, cuerpo, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: {title: titulo, body: cuerpo},
      data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v ?? "")]),
      ),
      android: {
        priority: "high",
        notification: {channelId: "pedidos"},
      },
      apns: {
        payload: {aps: {sound: "default"}},
      },
    });
  } catch (error) {
    console.error("Error enviando notificación:", error.message);
  }
}

function esRolNotificable(rol) {
  if (!rol) return false;
  const r = String(rol).toLowerCase();
  return r === "dueno" || r === "dueño" || r === "trabajador" || r === "owner";
}

async function obtenerUidsNotificarPedido(negocioId, negocioData) {
  const uids = new Set();
  const equipo = await db.collection("negocios").doc(negocioId).collection("equipo").get();
  for (const doc of equipo.docs) {
    const data = doc.data() || {};
    const rol = data.rol;
    const uid = data.uid || doc.id;
    if (esRolNotificable(rol) && uid) {
      uids.add(String(uid));
    }
  }
  const prop = negocioData?.propietario_uid;
  if (prop) uids.add(String(prop));
  for (const key of ["dueno_uid", "owner_uid", "usuario_id"]) {
    if (negocioData?.[key]) uids.add(String(negocioData[key]));
  }
  return [...uids];
}

function parseCitaInicio(raw) {
  if (!raw) return null;
  if (raw.toDate) return raw.toDate();
  const d = new Date(raw);
  return Number.isNaN(d.getTime()) ? null : d;
}

const DIAS_SEMANA_ES = [
  "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado",
];

function formatearFechaConDia(dt) {
  const dia = DIAS_SEMANA_ES[dt.getDay()];
  const d = String(dt.getDate()).padStart(2, "0");
  const m = String(dt.getMonth() + 1).padStart(2, "0");
  return `${dia} ${d}/${m}/${dt.getFullYear()}`;
}

function formatearCita(dt) {
  const h = dt.getHours();
  const h12 = h > 12 ? h - 12 : (h === 0 ? 12 : h);
  const ampm = h >= 12 ? "PM" : "AM";
  const min = String(dt.getMinutes()).padStart(2, "0");
  return `${formatearFechaConDia(dt)} · ${h12}:${min} ${ampm}`;
}

function resumenCitaEnPedido(pedido) {
  const productos = pedido.productos || [];
  for (const p of productos) {
    if (!p || typeof p !== "object") continue;
    const inicio = parseCitaInicio(p.cita_inicio);
    if (inicio) {
      const nombre = p.nombre || "Servicio";
      return `${nombre} · ${formatearCita(inicio)}`;
    }
  }
  if (pedido.metodo_entrega === "cita" || pedido.tiene_cita) {
    return "Nueva reserva en el local";
  }
  return null;
}

function mensajeNuevoPedido(pedido) {
  const negocio = pedido.negocio_nombre || "Tu negocio";
  const resumenCita = resumenCitaEnPedido(pedido);
  if (resumenCita) {
    return {titulo: "Nueva cita", cuerpo: `${negocio}: ${resumenCita}`};
  }
  const total = Number(pedido.total || 0).toFixed(2);
  const envio = Number(pedido.costo_envio || 0);
  const detalle = envio > 0 ?
    `Total \$${total} (envío \$${envio.toFixed(2)})` :
    `Total \$${total}`;
  return {titulo: "¡Nuevo pedido!", cuerpo: `${negocio}: ${detalle}`};
}

async function notificarDuenoNuevoPedido(pedidoId, pedido) {
  if (!pedido?.negocio_id) return {enviados: 0, motivo: "sin_negocio"};

  const ref = db.collection("pedidos").doc(pedidoId);
  const snap = await ref.get();
  if (snap.data()?.notificacion_dueno_enviada) {
    return {enviados: 0, motivo: "ya_enviada"};
  }

  const negocioSnap = await db.collection("negocios").doc(pedido.negocio_id).get();
  const negocioData = negocioSnap.data() || {};
  const uids = await obtenerUidsNotificarPedido(pedido.negocio_id, negocioData);

  if (uids.length === 0) {
    console.warn(
        `Sin destinatarios push para negocio ${pedido.negocio_id} (pedido ${pedidoId}). ` +
        "Agrega dueño en Equipo o propietario_uid.",
    );
    return {enviados: 0, motivo: "sin_uids"};
  }

  const {titulo, cuerpo} = mensajeNuevoPedido(pedido);
  let enviados = 0;
  for (const uid of uids) {
    const token = await obtenerTokenUsuario(uid);
    if (!token) {
      console.warn(`Usuario ${uid} sin fcm_token (pedido ${pedidoId})`);
      continue;
    }
    await enviarPush(token, titulo, cuerpo, {
      tipo: resumenCitaEnPedido(pedido) ? "nueva_cita" : "nuevo_pedido",
      pedido_id: pedidoId,
      negocio_id: pedido.negocio_id,
    });
    enviados++;
  }
  if (enviados > 0) {
    await ref.set({notificacion_dueno_enviada: true}, {merge: true});
  }
  return {enviados, motivo: enviados > 0 ? "ok" : "sin_tokens"};
}

exports.onNuevoPedido = onDocumentCreated("pedidos/{pedidoId}", async (event) => {
  const pedido = event.data?.data();
  if (!pedido?.negocio_id) return;

  try {
    const montoComision = Number(pedido.comision_app || 0);
    if (montoComision > 0 && pedido.estado !== "Cancelado") {
      await acumularComisionDesdePedido(pedido.negocio_id, pedido);
      await event.data.ref.update({comision_contabilizada: true});
    }
  } catch (error) {
    console.error("Error acumulando comisión:", error.message);
  }

  try {
    await notificarDuenoNuevoPedido(event.params.pedidoId, pedido);
  } catch (error) {
    console.error("Error notificando dueño:", error.message);
  }
});

exports.avisarNuevoPedido = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const pedidoId = request.data?.pedidoId;
  if (!pedidoId || typeof pedidoId !== "string") {
    throw new HttpsError("invalid-argument", "Falta pedidoId.");
  }

  const snap = await db.collection("pedidos").doc(pedidoId).get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Pedido no encontrado.");
  }
  const pedido = snap.data();
  if (pedido.cliente_id !== request.auth.uid) {
    throw new HttpsError("permission-denied", "No puedes avisar este pedido.");
  }

  return await notificarDuenoNuevoPedido(pedidoId, pedido);
});

exports.onPedidoEstadoActualizado = onDocumentUpdated("pedidos/{pedidoId}", async (event) => {
  const antes = event.data?.before?.data();
  const despues = event.data?.after?.data();
  if (!antes || !despues) return;
  if (antes.estado === despues.estado) return;

  if (despues.estado === "Cancelado" && antes.estado !== "Cancelado" && despues.negocio_id) {
    try {
      await revertirComisionDesdePedido(
          despues.negocio_id,
          event.params.pedidoId,
          despues,
      );
    } catch (error) {
      console.error("Error revirtiendo comisión:", error.message);
    }
  }

  const token = await obtenerTokenUsuario(despues.cliente_id);
  if (!token) return;

  const negocio = despues.negocio_nombre || "Tu pedido";
  const estado = despues.estado || "Actualizado";
  const esServicios = esPedidoServicios(despues);

  let titulo = "Actualización de pedido";
  let cuerpo = `${negocio}: ${estado}`;
  let tipo = "estado_pedido";

  if (esServicios && estado === "Confirmada") {
    titulo = "Cita confirmada";
    const resumen = resumenCitaEnPedido(despues);
    cuerpo = resumen ?
      `${negocio}: ${resumen}` :
      `${negocio}: tu cita está confirmada`;
    tipo = "cita_confirmada";
  } else if (esServicios && estado === "Cancelado") {
    titulo = "Cita cancelada";
    cuerpo = `${negocio}: tu cita fue cancelada`;
    tipo = "cita_cancelada";
  } else if (estado === "Preparando" && despues.tiempo_estimado) {
    cuerpo = `${negocio}: ${estado} · ${despues.tiempo_estimado}`;
  }

  await enviarPush(
      token,
      titulo,
      cuerpo,
      {
        tipo,
        pedido_id: event.params.pedidoId,
        estado,
      },
  );
});

function esPedidoServicios(pedido) {
  return pedido.tipo_negocio === "servicios" ||
    pedido.tiene_cita === true ||
    pedido.metodo_entrega === "cita" ||
    pedido.metodo_entrega === "servicio_solicitud";
}

exports.onComisionPagoRegistrado = onDocumentCreated(
    "negocios/{negocioId}/comision_pagos/{pagoId}",
    async (event) => {
      const pago = event.data?.data();
      const monto = Number(pago?.monto || 0);
      if (monto <= 0) return;
      if (pago?.procesado) return;

      try {
        await procesarPagoComision(
            event.params.negocioId,
            event.data.ref,
            monto,
        );
      } catch (error) {
        console.error("Error registrando pago de comisión:", error.message);
      }
    },
);

async function sincronizarAccesoUsuarioDesdeEquipo(negocioId, uid, equipoData, negocioData) {
  await db.collection("usuarios").doc(uid).collection("negocios_acceso").doc(negocioId).set({
    negocio_id: negocioId,
    rol: equipoData.rol || "trabajador",
    nombre: negocioData.nombre || "Sin nombre",
    categoria: negocioData.categoria || "",
    estado: negocioData.estado || "activo",
    foto_url: negocioData.foto_url || null,
    actualizado: FieldValue.serverTimestamp(),
  }, {merge: true});
}

exports.onEquipoMiembroCambiado = onDocumentWritten(
    "negocios/{negocioId}/equipo/{uid}",
    async (event) => {
      const negocioId = event.params.negocioId;
      const uid = event.params.uid;
      const accesoRef = db.collection("usuarios").doc(uid).collection("negocios_acceso").doc(negocioId);

      if (!event.data.after.exists) {
        try {
          await accesoRef.delete();
        } catch (error) {
          console.error("Error quitando acceso de usuario:", error.message);
        }
        return;
      }

      try {
        const negocioSnap = await db.collection("negocios").doc(negocioId).get();
        if (!negocioSnap.exists) return;
        await sincronizarAccesoUsuarioDesdeEquipo(
            negocioId,
            uid,
            event.data.after.data(),
            negocioSnap.data(),
        );
      } catch (error) {
        console.error("Error sincronizando acceso de equipo:", error.message);
      }
    },
);
