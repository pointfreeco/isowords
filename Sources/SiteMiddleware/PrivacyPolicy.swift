import Foundation
import HttpPipeline
import Prelude

func privacyPolicyMiddleware(
  _ conn: Conn<StatusLineOpen, Void>
) -> IO<Conn<ResponseEnded, Data>> {
  conn
    |> writeStatus(.ok)
    >=> respond(
      text: #"""
        Privacy Policy & Terms
        ======================

        Personal identification information
        -----------------------------------

        We collect device ID of registered Users. None of this information is sold or provided to third parties, except to provide the products and services you've requested, with your permission, or as required by law.

        Non-personal identification information
        ---------------------------------------

        We may collect non-personal identification information about Users whenever they interact with the App, This may include: the type of device, the operating system, and other similar information.

        How we use collected information
        --------------------------------

        Point-Free, Inc. collects and uses Users personal information for the following purposes:

        1. To personalize user experience: to understand how our Users as a group use the App.
        2. To improve our App.
        3. To improve customer service.
        4. To process transactions: We may use the information Users provide about themselves when placing an order only to provide service to that order. We do not share this information with outside parties except to the extent necessary to provide the service.
        5. To send periodic push notifications: The push tokens Users provide for order processing, will only be used to send them information and updates pertaining to their activity.

        How we protect your information
        -------------------------------

        We adopt appropriate data collection, storage and processing practices and security measures to protect against unauthorized access, alteration, disclosure or destruction of your personal information, username, password, transaction information and data stored on our Site.
        Sensitive and private data exchange between the Site and its Users happens over a SSL secured communication channel and is encrypted and protected with digital signatures.

        Sharing your personal information
        ---------------------------------

        We do not sell, trade, or rent Users' personal identification information to others.

        Compliance with children's online privacy protection act
        --------------------------------------------------------

        Protecting the privacy of the very young is especially important. For that reason, we never collect or maintain information at our Site from those we actually know are under 13, and no part of our website is structured to attract anyone under 13.

        Changes to this privacy policy
        ------------------------------

        Point-Free, Inc. has the discretion to update this privacy policy at any time. When we do, we will revise the updated date at the bottom of this page.

        Contacting us
        -------------

        Questions about this policy can be sent to support@pointfree.co.
        This document was last updated on March 9, 2021.
        """#)
}

//Privacy Policy
//
//Your privacy is important to us. It is Point-Free, Inc.'s policy to respect your privacy and comply with any applicable law and regulation regarding any personal information we may collect about you, including across our website, https://www.isowords.xyz, and other sites we own and operate.
//
//
//This policy is effective as of 10 March 2021 and was last updated on 10 March 2021.
//
//Information We Collect
//
//Information we collect includes both information you knowingly and actively provide us when using or participating in any of our services and promotions, and any information automatically sent by your devices in the course of accessing our products and services.
//
//Log Data
//
//When you visit our website, our servers may automatically log the standard data provided by your web browser. It may include your device’s Internet Protocol (IP) address, your browser type and version, the pages you visit, the time and date of your visit, the time spent on each page, other details about your visit, and technical details that occur in conjunction with any errors you may encounter.
//
//
//Please be aware that while this information may not be personally identifying by itself, it may be possible to combine it with other data to personally identify individual persons.
//
//Personal Information
//
//We may ask for personal information which may include one or more of the following:
//
//
//Name
//
//Legitimate Reasons for Processing Your Personal Information
//
//We only collect and use your personal information when we have a legitimate reason for doing so. In which instance, we only collect personal information that is reasonably necessary to provide our services to you.
//
//Collection and Use of Information
//
//We may collect personal information from you when you do any of the following on our website:
//
//
//Use a mobile device or web browser to access our content
//Contact us via email, social media, or on any similar technologies
//When you mention us on social media
//
//
//We may collect, hold, use, and disclose information for the following purposes, and personal information will not be further processed in a manner that is incompatible with these purposes:
//
//
//Please be aware that we may combine information we collect about you with general information or research data we receive from other trusted sources.
//
//Security of Your Personal Information
//
//When we collect and process personal information, and while we retain this information, we will protect it within commercially acceptable means to prevent loss and theft, as well as unauthorized access, disclosure, copying, use, or modification.
//
//
//Although we will do our best to protect the personal information you provide to us, we advise that no method of electronic transmission or storage is 100% secure, and no one can guarantee absolute data security. We will comply with laws applicable to us in respect of any data breach.
//
//
//You are responsible for selecting any password and its overall security strength, ensuring the security of your own information within the bounds of our services.
//
//How Long We Keep Your Personal Information
//
//We keep your personal information only for as long as we need to. This time period may depend on what we are using your information for, in accordance with this privacy policy. If your personal information is no longer required, we will delete it or make it anonymous by removing all details that identify you.
//
//
//However, if necessary, we may retain your personal information for our compliance with a legal, accounting, or reporting obligation or for archiving purposes in the public interest, scientific, or historical research purposes or statistical purposes.
//
//Children’s Privacy
//
//We do not aim any of our products or services directly at children under the age of 13, and we do not knowingly collect personal information about children under 13.
//
//International Transfers of Personal Information
//
//The personal information we collect is stored and/or processed where we or our partners, affiliates, and third-party providers maintain facilities. Please be aware that the locations to which we store, process, or transfer your personal information may not have the same data protection laws as the country in which you initially provided the information. If we transfer your personal information to third parties in other countries: (i) we will perform those transfers in accordance with the requirements of applicable law; and (ii) we will protect the transferred personal information in accordance with this privacy policy.
//
//Your Rights and Controlling Your Personal Information
//
//You always retain the right to withhold personal information from us, with the understanding that your experience of our website may be affected. We will not discriminate against you for exercising any of your rights over your personal information. If you do provide us with personal information you understand that we will collect, hold, use and disclose it in accordance with this privacy policy. You retain the right to request details of any personal information we hold about you.
//
//
//If we receive personal information about you from a third party, we will protect it as set out in this privacy policy. If you are a third party providing personal information about somebody else, you represent and warrant that you have such person’s consent to provide the personal information to us.
//
//
//If you have previously agreed to us using your personal information for direct marketing purposes, you may change your mind at any time. We will provide you with the ability to unsubscribe from our email-database or opt out of communications. Please be aware we may need to request specific information from you to help us confirm your identity.
//
//
//If you believe that any information we hold about you is inaccurate, out of date, incomplete, irrelevant, or misleading, please contact us using the details provided in this privacy policy. We will take reasonable steps to correct any information found to be inaccurate, incomplete, misleading, or out of date.
//
//
//If you believe that we have breached a relevant data protection law and wish to make a complaint, please contact us using the details below and provide us with full details of the alleged breach. We will promptly investigate your complaint and respond to you, in writing, setting out the outcome of our investigation and the steps we will take to deal with your complaint. You also have the right to contact a regulatory body or data protection authority in relation to your complaint.
//
//Limits of Our Policy
//
//Our website may link to external sites that are not operated by us. Please be aware that we have no control over the content and policies of those sites, and cannot accept responsibility or liability for their respective privacy practices.
//
//Changes to This Policy
//
//At our discretion, we may change our privacy policy to reflect updates to our business processes, current acceptable practices, or legislative or regulatory changes. If we decide to change this privacy policy, we will post the changes here at the same link by which you are accessing this privacy policy.
//
//
//If required by law, we will get your permission or give you the opportunity to opt in to or opt out of, as applicable, any new uses of your personal information.
//
//Contact Us
//
//For any questions or concerns regarding your privacy, you may contact us using the following details:
//
//
//Michael Williams
//support@pointfree.co
//
