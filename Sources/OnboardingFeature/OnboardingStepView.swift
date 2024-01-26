import ComposableArchitecture
import Styleguide
import SwiftUI

struct OnboardingStepView: View {
  @Bindable var store: StoreOf<Onboarding>
  @Environment(\.colorScheme) var colorScheme

  var body: some View {
    GeometryReader { proxy in
      let height = proxy.size.height / 4

      ZStack(alignment: .bottom) {
        VStack {
          if store.step.isFullscreen {
            Spacer()
          }

          Group {
            switch store.step {
            case .step1_Welcome:
              FullscreenStepView(
                Text("Hello!\nWelcome to ")
                + Text("isowords").fontWeight(.medium)
                + Text(", a word game.")
              )
            case .step2_FindWordsOnCube:
              FullscreenStepView(
                Text("The point of the game is to find words on a ")
                + Text("cube").fontWeight(.medium)
                + Text(".")
              )
            case .step3_ConnectLettersTouching:
              FullscreenStepView(
                Text("Words are formed by connecting letters that are ")
                + Text("touching").fontWeight(.medium)
                + Text(".")
              )
            case .step4_FindGame:
              InlineStepView(
                height: height,
                Text("Let’s try!\nConnect letters to form ")
                + Text("GAME").fontWeight(.medium)
                + Text(".")
              )
            case .step5_SubmitGame:
              InlineStepView(
                height: height,
                Text("Now submit the word by tapping the ")
                + Text("thumbs up").fontWeight(.medium)
                + Text(".")
              )
            case .step6_Congrats:
              InlineStepView(
                height: height,
                Text("Well done!")
              )
            case .step7_BiggerCube:
              FullscreenStepView(
                Text("Let’s find another word, but this time with more ")
                + Text("letters revealed").fontWeight(.medium)
                + Text(".")
              )
            case .step8_FindCubes:
              InlineStepView(
                height: height,
                Text("Find and submit the word ")
                + Text("CUBES").fontWeight(.medium)
                + Text(".")
              )
            case .step9_Congrats:
              InlineStepView(
                height: height,
                Text("You got it!")
              )
            case .step10_CubeDisappear:
              FullscreenStepView(
                Text("You can use each letter three times before the cube ")
                + Text("disappears").fontWeight(.medium)
                + Text(".")
              )
            case .step11_FindRemove:
              InlineStepView(
                height: height,
                Text("Let’s try it!\nFind the word ")
                + Text("REMOVE").fontWeight(.medium)
                + Text(".")
              )
            case .step12_CubeIsShaking:
              InlineStepView(
                height: height,
                Text("The shaking cube means it will ")
                + Text("disappear").fontWeight(.medium)
                + Text(". Now submit the word.")
              )
            case .step13_Congrats:
              InlineStepView(
                height: height,
                Text("Ohhhhhhh,\n").italic()
                + Text("interesting!")
              )
            case .step14_LettersRevealed:
              FullscreenStepView(
                Text(
                  "As cubes are removed the letters inside are revealed, helping you find more "
                )
                + Text("words").fontWeight(.medium)
                + Text(".")
              )
            case .step15_FullCube:
              FullscreenStepView(
                Text("Good job so far, but the real game is played with all letters ")
                + Text("revealed").fontWeight(.medium)
                + Text(".")
              )
            case .step16_FindAnyWord:
              InlineStepView(
                height: height,
                Text("Find ")
                + Text("any").fontWeight(.medium)
                + Text(" word on the full cube.")
              )
            case .step17_Congrats:
              InlineStepView(
                height: height,
                Text("That’s a great one!")
              )
            case .step18_OneLastThing:
              FullscreenStepView(
                Text("One last thing.\nYou can remove a cube by double-tapping it. ")
                + Text("This can be handy for exposing ")
                + Text("more letters").fontWeight(.medium)
                + Text(".")
              )
            case .step19_DoubleTapToRemove:
              InlineStepView(
                height: height,
                Text("Let’s try it.\nDouble tap any cube to ")
                + Text("remove").fontWeight(.medium)
                + Text(" it.")
              )
            case .step20_Congrats:
              InlineStepView(
                height: height,
                Text("Perfect!")
              )
            case .step21_PlayAGameYourself:
              switch store.presentationStyle {
              case .demo:
                FullscreenStepView(
                  Text("Ok, ready?\n Let’s try a 3 minute timed game!")
                )

              case .firstLaunch, .help:
                FullscreenStepView(
                  Text("Ok, there’s more strategy to the game, but the only way to learn is to ")
                  + Text("play a game yourself").fontWeight(.medium)
                  + Text("!")
                )
              }
            }
          }
          .foregroundColor(
            self.colorScheme == .dark
              ? store.step.color
              : Color.isowordsBlack
          )
          .transition(
            AnyTransition.asymmetric(
              insertion: .offset(x: 0, y: 50),
              removal: .offset(x: 0, y: -50)
            )
            .combined(with: .opacity)
          )
          // NB: The zIndex works around a bug. While transitioning a view
          //     out it will snap behind the cube view for some reason.
          .zIndex(1)
          .multilineTextAlignment(.center)

          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .adaptivePadding(.horizontal)
        .padding(.bottom, 80)

        Group {
          if store.isNextButtonVisible {
            Button {
              store.send(.nextButtonTapped, animation: .default)
            } label: {
              Image(systemName: "arrow.right")
                .frame(width: 80, height: 80)
                .background(
                  self.colorScheme == .dark
                    ? store.step.color
                    : Color.isowordsBlack
                )
                .foregroundColor(
                  self.colorScheme == .dark
                    ? Color.isowordsBlack
                    : store.step.color
                )
                .font(.system(size: 30))
                .clipShape(Circle())
            }
          } else if !store.step.isFullscreen {
            if store.isSubmitButtonVisible {
              Button {
                store.send(
                  .game(.submitButtonTapped(reaction: nil)), animation: .default
                )
              } label: {
                Image(systemName: "hand.thumbsup")
                  .frame(width: 80, height: 80)
                  .background(
                    self.colorScheme == .dark
                      ? store.step.color
                      : Color.isowordsBlack
                  )
                  .foregroundColor(
                    self.colorScheme == .dark
                      ? Color.isowordsBlack
                      : store.step.color
                  )
                  .font(.system(size: 30))
                  .clipShape(Circle())
              }
            }
          } else if store.isGetStartedButtonVisible {
            Button {
              store.send(.getStartedButtonTapped, animation: .default)
            } label: {
              HStack {
                switch store.presentationStyle {
                case .demo:
                  Text("Let’s play!")
                case .firstLaunch, .help:
                  Text("Get started")
                }
                Spacer()
                Image(systemName: "arrow.right")
              }
            }
            .buttonStyle(
              ActionButtonStyle(
                backgroundColor: self.colorScheme == .dark
                  ? store.step.color
                  : .isowordsBlack,
                foregroundColor: self.colorScheme == .dark
                  ? .isowordsBlack
                  : store.step.color
              )
            )
          }
        }
        .padding()
        .transition(
          .asymmetric(
            insertion: .offset(x: 0, y: 50),
            removal: .offset(x: 0, y: 50)
          )
          .combined(with: .opacity)
        )
      }
    }
    .task { await store.send(.task).finish() }
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

private struct FullscreenStepView: View {
  let text: Text

  init(_ text: Text) {
    self.text = text
  }

  var body: some View {
    self.text
      .adaptiveFont(.matter, size: 40)
      .minimumScaleFactor(0.2)
  }
}

private struct InlineStepView: View {
  let height: CGFloat
  let text: Text

  init(height: CGFloat, _ text: Text) {
    self.height = height
    self.text = text
  }

  var body: some View {
    self.text
      .adaptiveFont(.matter, size: 28)
      .minimumScaleFactor(0.2)
      .frame(height: self.height)
  }
}

fileprivate extension Onboarding.State {
  var isGetStartedButtonVisible: Bool { self.step == Onboarding.State.Step.allCases.last }
  var isNextButtonVisible: Bool {
    self.step != Onboarding.State.Step.allCases.first
      && self.step.isFullscreen
      && self.step != Onboarding.State.Step.allCases.last
  }
  var isSubmitButtonVisible: Bool {
    switch self.step {
    case .step5_SubmitGame:
      return self.game.selectedWordString == "GAME"
    case .step8_FindCubes:
      return self.game.selectedWordString == "CUBES"
    case .step12_CubeIsShaking:
      return self.game.selectedWordString.isRemove
    case .step16_FindAnyWord:
      return !self.game.selectedWordString.isEmpty
    default:
      return false
    }
  }
}

extension Onboarding.State.Step {
  var color: Color {
    let t = Double(self.rawValue) / Double(Self.allCases.count - 1)
    return Color(
      red: (t * 0xE1 + (1 - t) * 0xF3) / 0xFF,
      green: (t * 0x66 + (1 - t) * 0xEB) / 0xFF,
      blue: (t * 0x5B + (1 - t) * 0xA4) / 0xFF
    )
  }
}

#if DEBUG
  import Overture
  import SwiftUIHelpers

  struct OnboardingStepView_Previews: PreviewProvider {
    static var previews: some View {
      Preview {
        OnboardingStepView(
          store: Store(
            initialState: Onboarding.State(
              presentationStyle: .firstLaunch,
              step: .step16_FindAnyWord
            )
          ) {
            Onboarding()
          }
        )
      }
    }
  }
#endif
