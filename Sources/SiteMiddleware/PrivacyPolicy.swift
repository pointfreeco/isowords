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

        We collect device ID of registered Users. None of this information is sold or provided to third parties, except to provide the products and services you’ve requested, with your permission, or as required by law.

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

        We do not sell, trade, or rent Users’ personal identification information to others.

        Compliance with children’s online privacy protection act
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
