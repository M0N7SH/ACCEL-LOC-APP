const functions = require("firebase-functions");
const nodemailer = require("nodemailer");

// Configure your Gmail credentials here
const GMAIL_EMAIL = "monish2210858@ssn.edu.in";
const GMAIL_APP_PASSWORD = "OECpsWYv";

// Create reusable transporter object using Gmail SMTP
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: GMAIL_EMAIL,
    pass: GMAIL_APP_PASSWORD,
  },
});

exports.sendPasswordEmail = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const password = data.password;

  if (!email || !password) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and password must be provided.",
    );
  }

  const mailOptions = {
    from: GMAIL_EMAIL,
    to: email,
    subject: "Your Account Password",
    text: `Hello,

Your account password is: ${password}

Please keep it safe.

Best regards,
Admin Team`,
  };

  try {
    await transporter.sendMail(mailOptions);
    return {success: true, message: `Email sent to ${email}`};
  } catch (error) {
    console.error("Error sending email:", error);
    throw new functions.https.HttpsError("internal", "Failed to send email");
  }
});
