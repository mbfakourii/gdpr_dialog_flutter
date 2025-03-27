import Flutter
import UIKit
import UserMessagingPlatform // UMP SDK made for Google Mobile Ads

// Class for work with GDPR Consent Form
// and for work with Consent Statuses
public class SwiftGdprDialogPlugin: NSObject, FlutterPlugin {
        
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "gdpr_dialog", binaryMessenger: registrar.messenger())
    let instance = SwiftGdprDialogPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch (call.method) {
      case "gdpr.activate":
        let arg = call.arguments as? NSDictionary
        let isTest = arg!["isForTest"] as? Bool;
        let deviceId = arg!["testDeviceId"] as? String;
        
        self.checkConsent(result: result, isForTest: isTest!, testDeviceId: deviceId!)

      case "gdpr.getConsentStatus":
        self.getConsentStatus(result: result);
      case "gdpr.reset":
        self.resetDecision(result: result);
      default:
        result(FlutterMethodNotImplemented)
    }
  }
  
  // Possible returned values:
  //
  // `OBTAINED` status means, that user already chose one of the variants
  // ('Consent' or 'Do not consent');
  //
  // `REQUIRED` status means, that form should be shown by user, because his
  // location is at EEA or UK;
  //
  // `NOT_REQUIRED` status means, that form would not be shown by user, because
  // his location is not at EEA or UK;
  //
  // `UNKNOWN` status means, that there is no information about user location.
  private func getConsentStatus(result: @escaping FlutterResult) {
    var statusResult = "ERROR"
    do {
      let status = ConsentInformation.shared.consentStatus
      if status == .notRequired {
        print(".notRequired");
        statusResult = "NOT_REQUIRED"
      } else if status == .required {
        print(".required");
        statusResult = "REQUIRED"
      } else if status == .obtained {
        print(".obtained");
        statusResult = "OBTAINED"
      } else if status == .unknown {
        print(".unknown");
        statusResult = "UNKNOWN"
      }
    } catch let error {
      print("Error on getConsentStatus: \(error)")
    }
    result(statusResult)
  }

  private func checkConsent(result: @escaping FlutterResult, isForTest: Bool, testDeviceId: String) {
    let parameters = RequestParameters()
    // Set tag for under age of consent. Here false means users are not under age.
    parameters.isTaggedForUnderAgeOfConsent = false

    if isForTest {
      let debugSettings = DebugSettings()
      debugSettings.testDeviceIdentifiers = [ testDeviceId ]
      debugSettings.geography = DebugGeography.EEA
      parameters.debugSettings = debugSettings
    }

    // Request an update to the consent information.
    ConsentInformation.shared.requestConsentInfoUpdate(
        with: parameters,
        completionHandler: { [self] error in

          // The consent information has updated.
          if error != nil {
            print("Error on requestConsentInfoUpdate: \(error)")
            result(false)
          } else {
            // The consent information state was updated.
            // You are now ready to see if a form is available.
            let formStatus = ConsentInformation.shared.formStatus
            if formStatus == FormStatus.available {
              loadForm(result: result)
            } else if formStatus == FormStatus.unavailable {
              // Consent forms are unavailable. Showing a consent form is not required.
              result(true)
            }
          }
        })
  }

  private func loadForm(result: @escaping FlutterResult) {
    ConsentForm.load(
      with: { form, loadError in
        if loadError != nil {
          print("Error on loadForm: \(loadError)")
          result(false)
        } else {
          // Present the form. You can also hold on to the reference to present
          // later.
          if ConsentInformation.shared.consentStatus == ConsentStatus.required {
            form?.present(
              from: (UIApplication.shared.delegate?.window?!.rootViewController)!,
                completionHandler: { dismissError in
                  if dismissError != nil {
                    print("Error on loadForm completionHandler: \(dismissError)")
                    result(false)
                  }
                  // else {
                  //   if ConsentInformation.shared.consentStatus == ConsentStatus.obtained {
                  //     --- App can start requesting ads. ---
                  //   }
                  // }
                })
          }
          result(true)
        }
      })
  }

  // In testing your app with the UMP SDK, you may find it helpful
  // to reset the state of the SDK so that you can simulate
  // a user's first install experience.
  private func resetDecision(result: @escaping FlutterResult) {
    do {
      ConsentInformation.shared.reset()
      result(true)
    } catch let error {
      print("Error on resetDecision: \(error)")
      result(false)
    }
  }
}