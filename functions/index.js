const {setGlobalOptions} = require("firebase-functions");
const {onRequest} = require("firebase-functions/https");
const logger = require("firebase-functions/logger");

setGlobalOptions({ maxInstances: 10 });

const functions = require("firebase-functions");
const stripe = require("stripe")("sk_test_51TDADeFKKt6Soe1vp3MNRchO9Mo2qF4PFcT9gwrpXjxwiKwmBQYGTZoXw6rxeXXur5bwLfSZlMcAoLyOF3JhqHuF00zfSNJiix"); 

exports.crearIntentoDePago = functions.https.onCall(async (data, context) => {
    try {
        const payload = data.total !== undefined ? data : data.data;
        if (!payload || payload.total === undefined) {
            throw new Error("No se encontró la variable 'total'.");
        }
        const totalMxn = parseFloat(payload.total); 
        if (isNaN(totalMxn) || totalMxn <= 0) {
            throw new Error("El total recibido no es un número válido.");
        }
        const amountInCents = Math.round(totalMxn * 100);
        const paymentIntent = await stripe.paymentIntents.create({
            amount: amountInCents,
            currency: 'mxn',
        });
        return { clientSecret: paymentIntent.client_secret };
    } catch (error) {
        throw new functions.https.HttpsError('internal', error.message);
    }
});

exports.reembolsarPago = functions.https.onCall(async (data, context) => {
    // Ya no usamos JSON.stringify para evitar el crash circular
    console.log("Iniciando proceso de reembolso...");
    
    try {
        let paymentIntentId = null;
        if (data && data.paymentIntentId) {
            paymentIntentId = data.paymentIntentId;
        } else if (data && data.data && data.data.paymentIntentId) {
            paymentIntentId = data.data.paymentIntentId;
        }

        if (!paymentIntentId) {
            console.error("Fallo: No llegó el paymentIntentId.");
            throw new functions.https.HttpsError('invalid-argument', 'Falta el ID del pago para reembolsar.');
        }

        console.log("Enviando orden a Stripe para el pago:", paymentIntentId);
        
        const refund = await stripe.refunds.create({
            payment_intent: paymentIntentId,
        });

        console.log("¡Reembolso exitoso! ID:", refund.id);
        return { success: true, refundId: refund.id };
        
    } catch (error) {
        console.error("Error al reembolsar:", error.message);
        throw new functions.https.HttpsError('internal', error.message);
    }
});