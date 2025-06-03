const express = require("express");
const nodemailer = require("nodemailer");
const cors = require("cors");
require("dotenv").config();

const app = express();
app.use(cors());
app.use(express.json());

const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.GMAIL_EMAIL,
    pass: process.env.GMAIL_APP_PASSWORD,
  },
});

app.post("/send-password", async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ success: false, message: "Missing fields" });
  }

  const mailOptions = {
    from: process.env.GMAIL_EMAIL,
    to: email,
    subject: "Your Account Password",
    text: `Hello,\n\nYour account password is: ${password}\n\nPlease keep it safe.\n\nRegards,\nAdmin Team`,
  };

  try {
    await transporter.sendMail(mailOptions);
    res.status(200).json({ success: true, message: `Email sent to ${email}` });
  } catch (error) {
    console.error("Email send error:", error);
    res.status(500).json({ success: false, message: "Failed to send email" });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));
