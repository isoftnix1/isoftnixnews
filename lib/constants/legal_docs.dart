class LegalDocs {
  static const String privacyPolicy = '''
# Privacy Policy

**Last Updated:** July 11, 2026

**iSoftNix News** (referred to as "Company", "we", "our", or "us") is committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy ("Policy") outlines our practices regarding the collection, use, processing, and disclosure of information that you provide to us through our Android mobile application ("App") and related services (collectively, the "Services").

By downloading, accessing, or using the App, you agree to the terms of this Privacy Policy. If you do not agree with the practices described in this Policy, please do not use the Services.

*Note: This Policy currently applies specifically to our Android application. iOS-specific terms will be incorporated when the iOS version is made publicly available.*

---

## 1. Information We Collect

We collect information to provide, personalize, and improve our Services. The information we collect falls into two broad categories: Information you provide to us directly, and Information we collect automatically.

### 1.1. Information You Provide to Us
When you register for an account or interact with our Services, we may ask you to provide certain personal information, which includes:
*   **Account Information:** Your Name, Email Address, Phone Number (optional), and Password.
*   **User-Generated Content:** If you have administrative or publishing rights, you may upload news content, images, and videos.

### 1.2. Information We Collect Automatically
When you use the App, our backend servers (Node.js/Express) and third-party integrations automatically collect certain information about your device and interaction with the Services:
*   **Device Information:** We collect device-specific information such as your hardware model, operating system version, unique device identifiers (hardware fingerprints), and mobile network information. This is strictly used for securing administrative accounts and preventing unauthorized access.
*   **Usage Data:** We track how you interact with the App, including the articles you read, the time spent on the App, and your language preferences (e.g., English, Hindi, Marathi).
*   **Push Notification Tokens:** We collect Firebase Cloud Messaging (FCM) tokens to send you breaking news and app updates. Our servers also run heartbeat checks to detect if the App has been uninstalled or is inactive.

### 1.3. Information Collected via Device Permissions
To provide enhanced features, we may request your explicit permission to access specific device capabilities. You can enable or disable these permissions at any time through your Android device settings:
*   **Location Information (GPS Tracking):** With your permission, we collect your precise or approximate location (Foreground and Background). This allows us to serve you hyper-local news, relevant weather updates, and region-specific content.
*   **Camera and Photo Library:** With your permission, we access your device’s camera and photo gallery to allow you to upload images and videos directly to news articles or your profile.
*   **Microphone Access:** If you choose to record video footage for news uploads, we will require microphone access to capture the accompanying audio.

### 1.4. Future Services
Please note that in the future, we plan to introduce additional features including a Payment Wallet, Trade Rates, and Export Rates functionality. When these features are implemented, this Privacy Policy will be updated to reflect the additional financial and transactional data we may collect to facilitate those services.

---

## 2. How We Use Your Information

We use the collected information for various operational and legal purposes, including:
*   **Service Delivery:** To create your account, authenticate your logins, and deliver personalized news feeds.
*   **Security and Fraud Prevention:** To enforce strict hardware-locking mechanisms for administrative accounts, preventing unauthorized access from unrecognized devices.
*   **Communication:** To send you administrative notices, OTPs for password resets, and push notifications regarding breaking news.
*   **Analytics and Improvement:** To analyze user trends, track article views, monitor App performance, and troubleshoot crashes using Firebase Analytics.

---

## 3. How We Share Your Information

We do not sell your personal data. We may share your information only in the following limited circumstances:
*   **Service Providers:** We engage trusted third-party companies to perform services on our behalf. For example, we use **Cloudinary** for secure cloud storage of media uploads, and **Google Firebase** for analytics and push notifications. These providers have access to your data only to perform these tasks on our behalf.
*   **Legal Compliance:** We may disclose your information if required to do so by law, court order, or governmental request, or to protect the rights, property, or safety of iSoftNix, our users, or others.

---

## 4. Data Security

We implement robust, industry-standard security measures to protect your data from unauthorized access, alteration, or destruction:
*   **Data in Transit:** All communication between the App and our backend servers is encrypted using HTTPS/SSL.
*   **Data at Rest:** Passwords are securely hashed using bcrypt. Sensitive authentication tokens (JWTs) are stored locally on your device using native Android Keystore encryption (`flutter_secure_storage`).

---

## 5. Data Retention

We retain your personal information for as long as your account is active or as needed to provide you with the Services. 
*   **Automated Cleanup:** We utilize automated background processes to detect inactive devices and purge stale FCM tokens and heartbeat logs after 30 days of inactivity.
*   If you choose to delete your account, your personal data will be permanently removed from our active PostgreSQL database.

---

## 6. Your Rights and Choices

*   **Account Deletion:** You have the right to request the deletion of your account and personal data at any time through the "Settings" menu within the App.
*   **Permission Management:** You can revoke the App's access to your Camera, Microphone, Location, and Storage at any time via your Android device’s Settings app. Note that revoking permissions may disable certain features of the App.

---

## 7. Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect changes in our practices, technology, or legal requirements. We will notify you of any material changes by posting the new Privacy Policy within the App and updating the "Last Updated" date. Your continued use of the App after such changes constitutes your acceptance of the revised Policy.

---

## 8. Contact Us

If you have any questions, concerns, or grievances regarding this Privacy Policy or our data practices, please contact our support team at:
**Email:** isoftnix1@gmail.com
''';

  static const String termsAndConditions = '''
# Terms and Conditions

**Last Updated:** July 11, 2026

Welcome to the **iSoftNix News** application ("App"). These Terms and Conditions ("Terms") govern your download, access, and use of the iSoftNix News Android application and its associated backend services (collectively, the "Services"), provided by iSoftNix ("Company", "we", "us", or "our").

By downloading, installing, or using the App, you signify your agreement to these Terms. If you do not agree to these Terms, you may not access or use the App.

*Note: These Terms currently apply specifically to our Android application. iOS-specific terms will be incorporated when the iOS version is made publicly available.*

---

## 1. Use of the Services

**1.1. Eligibility:** You must be at least 13 years old (or the minimum legal age in your country) to use the App. By using the App, you represent and warrant that you meet this age requirement.

**1.2. Account Registration:** To access certain features, you may be required to register for an account. You agree to provide accurate, current, and complete information during the registration process and to keep your account information updated.

**1.3. Account Security:** You are responsible for safeguarding your password and authentication tokens. We utilize strict hardware-locking mechanisms (device fingerprinting) to secure administrative accounts. You agree not to attempt to bypass these security protocols or access accounts belonging to other users.

---

## 2. Content and Intellectual Property Rights

**2.1. Our Content:** The App, including its text, graphics, user interfaces, visual interfaces, photographs, trademarks, logos, sounds, music, artwork, and computer code (including the Flutter frontend and Node.js backend), is owned, controlled, or licensed by or to iSoftNix and is protected by copyright, patent, and trademark laws.

**2.2. License to Use:** We grant you a personal, non-exclusive, non-transferable, limited privilege to enter and use the App strictly for your personal, non-commercial use.

**2.3. Restrictions:** Except as expressly provided in these Terms, no part of the App and no Content may be copied, reproduced, republished, uploaded, posted, publicly displayed, encoded, translated, transmitted, or distributed in any way to any other computer, server, website, or other medium for publication or distribution without our express prior written consent. You may, however, use the built-in sharing features of the App to share links to news articles.

---

## 3. User-Generated Content and Media Uploads

**3.1. Admin and Publisher Uploads:** Users granted administrative or publishing rights may upload content, including text, images, and videos ("User Content"). 

**3.2. User Responsibility:** You retain all of your ownership rights in your User Content. However, by uploading User Content, you grant us a worldwide, non-exclusive, royalty-free, transferable license to use, reproduce, distribute, and display that content in connection with the Services.

**3.3. Prohibited Content:** You agree not to upload any User Content that is:
*   Defamatory, libelous, obscene, pornographic, or offensive.
*   Violative of any third party's copyright, trademark, or privacy rights.
*   Malicious in nature, including content containing software viruses or malware.

We reserve the right to remove any User Content at our sole discretion without prior notice.

---

## 4. Third-Party Services and Links

The App may contain links to other independent third-party websites or services (e.g., rendering articles via in-app webviews). These third-party sites are not under our control, and we are not responsible for and do not endorse their content or privacy practices. Your use of third-party services, including Cloudinary for media storage and Firebase for analytics, is subject to their respective terms and conditions.

---

## 5. Disclaimers and Limitation of Liability

**5.1. Disclaimer of Warranties:** THE APP AND ITS CONTENT ARE DELIVERED ON AN "AS-IS" AND "AS-AVAILABLE" BASIS. ALL INFORMATION PROVIDED ON THE APP IS SUBJECT TO CHANGE WITHOUT NOTICE. WE DISCLAIM ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING ANY WARRANTIES OF ACCURACY, NON-INFRINGEMENT, MERCHANTABILITY, AND FITNESS FOR A PARTICULAR PURPOSE.

**5.2. Limitation of Liability:** EXCEPT WHERE PROHIBITED BY LAW, IN NO EVENT WILL ISOFTNIX BE LIABLE TO YOU FOR ANY INDIRECT, CONSEQUENTIAL, EXEMPLARY, INCIDENTAL, OR PUNITIVE DAMAGES, INCLUDING LOST PROFITS OR DATA LOSS ARISING FROM YOUR USE OF THE APP, EVEN IF WE HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

---

## 6. Violation of These Terms

We may disclose any information we have about you if we determine that such disclosure is necessary in connection with any investigation or complaint regarding your use of the App. We reserve the right at all times to terminate your access to the App, without notice, if we determine you have violated these Terms or other associated guidelines.

---

## 7. Governing Law and Dispute Resolution

These Terms and your use of the App will be governed by and construed in accordance with the laws of the jurisdiction in which iSoftNix operates, without regard to its conflict of law provisions. Any dispute arising out of or relating to these Terms or the App shall be subject to the exclusive jurisdiction of the competent courts in that region.

---

## 8. Changes to the Terms

We reserve the right, at our sole discretion, to change, modify, add, or remove portions of these Terms at any time. It is your responsibility to check these Terms periodically for changes. Your continued use of the App following the posting of changes will mean that you accept and agree to the changes.

## 9. Contact Us

If you have any questions or feedback regarding these Terms, please contact us at:
**Email:** isoftnix1@gmail.com
''';
}
