package com.example.the_guardian_v1.service.impl;

import com.example.the_guardian_v1.service.IEmailService;
import jakarta.mail.MessagingException;
import jakarta.mail.internet.MimeMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.stereotype.Service;

@Service
public class EmailServiceImpl implements IEmailService {

    private final JavaMailSender mailSender;

    public EmailServiceImpl(JavaMailSender mailSender) {
        this.mailSender = mailSender;
    }

    @Override
    public void sendOtpEmail(String toEmail, String otpCode) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, true, "UTF-8");

            helper.setTo(toEmail);
            helper.setSubject("The Guardian - Votre code de vérification");

            String htmlContent = buildOtpEmailHtml(otpCode);
            helper.setText(htmlContent, true);

            mailSender.send(message);
        } catch (MessagingException e) {
            throw new RuntimeException("Failed to send OTP email to " + toEmail, e);
        }
    }

    private String buildOtpEmailHtml(String otpCode) {
        return """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="UTF-8">
                    <style>
                        body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 0; }
                        .container { max-width: 600px; margin: 40px auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                        .header { background-color: #6366f1; color: #ffffff; padding: 30px; text-align: center; }
                        .header h1 { margin: 0; font-size: 28px; }
                        .content { padding: 40px 30px; }
                        .otp-box { background-color: #f8f9fa; border: 2px dashed #6366f1; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0; }
                        .otp-code { font-size: 36px; font-weight: bold; color: #6366f1; letter-spacing: 8px; margin: 10px 0; }
                        .footer { background-color: #f8f9fa; padding: 20px; text-align: center; font-size: 12px; color: #6b7280; }
                        p { line-height: 1.6; color: #374151; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>🛡️ The Guardian</h1>
                        </div>
                        <div class="content">
                            <h2 style="color: #1f2937;">Vérification de votre compte</h2>
                            <p>Bonjour,</p>
                            <p>Merci de vous être inscrit à The Guardian. Pour compléter votre inscription, veuillez utiliser le code de vérification ci-dessous :</p>

                            <div class="otp-box">
                                <p style="margin: 0; font-size: 14px; color: #6b7280;">Votre code de vérification</p>
                                <div class="otp-code">"""
                + otpCode
                + """
                                        </div>
                                        <p style="margin: 0; font-size: 12px; color: #6b7280;">Ce code expire dans 10 minutes</p>
                                    </div>

                                    <p>Si vous n'avez pas demandé ce code, veuillez ignorer cet email.</p>
                                    <p>Cordialement,<br>L'équipe The Guardian</p>
                                </div>
                                <div class="footer">
                                    <p>Cet email a été envoyé automatiquement, merci de ne pas y répondre.</p>
                                    <p>&copy; 2026 The Guardian. Tous droits réservés.</p>
                                </div>
                            </div>
                        </body>
                        </html>
                        """;
    }
}
