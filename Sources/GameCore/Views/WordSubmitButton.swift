import AudioPlayerClient
import ComposableArchitecture
import FeedbackGeneratorClient
import SharedModels
import SwiftUI

public struct WordSubmitButtonFeatureState: Equatable {
  public var isSelectedWordValid: Bool
  public let isTurnBasedMatch: Bool
  public let isYourTurn: Bool
  public var wordSubmitButton: WordSubmitButtonState

  public init(
    isSelectedWordValid: Bool,
    isTurnBasedMatch: Bool,
    isYourTurn: Bool,
    wordSubmitButton: WordSubmitButtonState
  ) {
    self.isSelectedWordValid = isSelectedWordValid
    self.isTurnBasedMatch = isTurnBasedMatch
    self.isYourTurn = isYourTurn
    self.wordSubmitButton = wordSubmitButton
  }
}

public struct WordSubmitButtonState: Equatable {
  public var areReactionsOpen: Bool
  public var favoriteReactions: [Move.Reaction]
  public var isClosing: Bool
  public var isSubmitButtonPressed: Bool

  public init(
    areReactionsOpen: Bool = false,
    favoriteReactions: [Move.Reaction] = Move.Reaction.allCases,
    isClosing: Bool = false,
    isSubmitButtonPressed: Bool = false
  ) {
    self.areReactionsOpen = areReactionsOpen
    self.favoriteReactions = favoriteReactions
    self.isClosing = isClosing
    self.isSubmitButtonPressed = isSubmitButtonPressed
  }
}

public enum WordSubmitButtonAction: Equatable {
  case backgroundTapped
  case delayedSubmitButtonPressed
  case delegate(DelegateAction)
  case reactionButtonTapped(Move.Reaction)
  case submitButtonPressed
  case submitButtonReleased
  case submitButtonTapped

  public enum DelegateAction: Equatable {
    case confirmSubmit(reaction: Move.Reaction?)
  }
}

struct WordSubmitEnvironment {
  let audioPlayer: AudioPlayerClient
  let feedbackGenerator: FeedbackGeneratorClient
  let mainQueue: AnySchedulerOf<DispatchQueue>
}

let wordSubmitReducer = Reducer<
  WordSubmitButtonFeatureState, WordSubmitButtonAction, WordSubmitEnvironment
> { state, action, environment in

  struct SubmitButtonPressedDelayId: Hashable {}

  guard state.isYourTurn
  else { return .none }

  switch action {
  case .backgroundTapped:
    state.wordSubmitButton.areReactionsOpen = false
    return environment.audioPlayer.play(.uiSfxEmojiClose)
      .fireAndForget()

  case .delayedSubmitButtonPressed:
    state.wordSubmitButton.areReactionsOpen = true
    return .merge(
      environment.feedbackGenerator.selectionChanged()
        .fireAndForget(),

      environment.audioPlayer.play(.uiSfxEmojiOpen)
        .fireAndForget()
    )

  case .delegate:
    return .none

  case let .reactionButtonTapped(reaction):
    state.wordSubmitButton.areReactionsOpen = false
    return .merge(
      environment.feedbackGenerator.selectionChanged()
        .fireAndForget(),

      environment.audioPlayer.play(.uiSfxEmojiSend)
        .fireAndForget(),

      Effect(value: .delegate(.confirmSubmit(reaction: reaction)))
    )

  case .submitButtonPressed:
    guard state.isTurnBasedMatch
    else { return .none }

    let closeSound: Effect<Never, Never>
    if state.wordSubmitButton.areReactionsOpen {
      state.wordSubmitButton.isClosing = true
      closeSound = environment.audioPlayer.play(.uiSfxEmojiClose)
    } else {
      closeSound = .none
    }
    state.wordSubmitButton.areReactionsOpen = false
    state.wordSubmitButton.isSubmitButtonPressed = true

    let longPressEffect: Effect<WordSubmitButtonAction, Never>
    if state.isSelectedWordValid {
      longPressEffect = Effect(value: .delayedSubmitButtonPressed)
        .delay(for: 0.5, scheduler: environment.mainQueue)
        .eraseToEffect()
        .cancellable(id: SubmitButtonPressedDelayId(), cancelInFlight: true)
    } else {
      longPressEffect = .none
    }

    return .merge(
      longPressEffect,

      closeSound
        .fireAndForget(),

      environment.feedbackGenerator.selectionChanged()
        .fireAndForget()
    )

  case .submitButtonReleased:
    guard state.isTurnBasedMatch
    else { return .none }

    let wasClosing = state.wordSubmitButton.isClosing
    state.wordSubmitButton.isClosing = false
    state.wordSubmitButton.isSubmitButtonPressed = false
    return .merge(
      .cancel(id: SubmitButtonPressedDelayId()),

      wasClosing || state.wordSubmitButton.areReactionsOpen
        ? .none
        : Effect(value: .delegate(.confirmSubmit(reaction: nil)))
    )

  case .submitButtonTapped:
    guard !state.isTurnBasedMatch
    else { return .none }

    return Effect(value: .delegate(.confirmSubmit(reaction: nil)))
  }
}

public struct WordSubmitButton: View {
  @Environment(\.deviceState) var deviceState
  let store: Store<WordSubmitButtonFeatureState, WordSubmitButtonAction>
  @ObservedObject var viewStore: ViewStore<WordSubmitButtonFeatureState, WordSubmitButtonAction>
  @State var isTouchDown = false

  public init(
    store: Store<WordSubmitButtonFeatureState, WordSubmitButtonAction>
  ) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  public var body: some View {
    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
      if self.viewStore.wordSubmitButton.areReactionsOpen {
        RadialGradient(
          gradient: Gradient(colors: [.white, Color.white.opacity(0)]),
          center: .bottom,
          startRadius: 0,
          endRadius: 350
        )
        .transition(.opacity)
      }

      VStack {
        Spacer()

        ZStack {
          ReactionsView(store: self.store.scope(state: \.wordSubmitButton))

          Button(action: {
            self.viewStore.send(.submitButtonTapped, animation: .default)
          }) {
            Group {
              if !self.viewStore.wordSubmitButton.areReactionsOpen {
                Image(systemName: "hand.thumbsup")
              } else {
                Image(systemName: "xmark")
              }
            }
            .frame(
              width: self.deviceState.idiom == .pad ? 100 : 80,
              height: self.deviceState.idiom == .pad ? 100 : 80
            )
            .background(Circle().fill(Color.adaptiveBlack))
            .foregroundColor(.adaptiveWhite)
            .opacity(self.viewStore.isSelectedWordValid ? 1 : 0.5)
            .font(.system(size: self.deviceState.isPad ? 40 : 30))
            .adaptivePadding([.all], .grid(4))
            // NB: Expand the tappable radius of the button.
            .background(Color.black.opacity(0.0001))
          }
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { touch in
                if !self.isTouchDown {
                  self.viewStore.send(.submitButtonPressed, animation: .default)
                }
                self.isTouchDown = true
              }
              .onEnded { _ in
                self.viewStore.send(.submitButtonReleased, animation: .default)
                self.isTouchDown = false
              }
          )
        }
        .padding()
      }

    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(
      self.viewStore.wordSubmitButton.areReactionsOpen
        ? Color.isowordsBlack.opacity(0.4)
        : nil
    )
    .animation(.default)
    .onTapGesture {
      self.viewStore.send(.backgroundTapped, animation: .default)
    }
  }
}

struct ReactionsView: View {
  let store: Store<WordSubmitButtonState, WordSubmitButtonAction>
  @ObservedObject var viewStore: ViewStore<WordSubmitButtonState, WordSubmitButtonAction>

  public init(store: Store<WordSubmitButtonState, WordSubmitButtonAction>) {
    self.store = store
    self.viewStore = ViewStore(self.store)
  }

  var body: some View {
    ForEach(Array(self.viewStore.favoriteReactions.enumerated()), id: \.offset) { idx, reaction in
      let offset = self.offset(index: idx)

      Button(action: { self.viewStore.send(.reactionButtonTapped(reaction), animation: .default) })
      {
        Text(reaction.rawValue)
          .font(.system(size: 32))
          .padding()
      }
      .background(Color.white.opacity(0.5))
      .clipShape(Circle())
      .rotationEffect(.degrees(self.viewStore.areReactionsOpen ? -360 : 0))
      .opacity(self.viewStore.areReactionsOpen ? 1 : 0)
      .offset(x: offset.x, y: offset.y)
      .animation(
        Animation.default.delay(Double(idx) / Double(self.viewStore.favoriteReactions.count * 10))
      )
    }
  }

  func offset(index: Int) -> CGPoint {
    let angle: CGFloat =
      CGFloat.pi / CGFloat(self.viewStore.favoriteReactions.count - 1) * CGFloat(index) + .pi

    return .init(
      x: self.viewStore.areReactionsOpen ? cos(angle) * 130 : 0,
      y: self.viewStore.areReactionsOpen ? sin(angle) * 130 : 0
    )
  }
}

#if DEBUG
  struct WordSubmitButton_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        WordSubmitButton(
          store: .init(
            initialState: WordSubmitButtonFeatureState(
              isSelectedWordValid: true,
              isTurnBasedMatch: true,
              isYourTurn: true,
              wordSubmitButton: .init()
            ),
            reducer: wordSubmitReducer,
            environment: WordSubmitEnvironment(
              audioPlayer: .noop,
              feedbackGenerator: .live,
              mainQueue: .main
            )
          )
        )
        .background(Color.blue)
        .navigationBarHidden(true)
      }
      .previewDevice("iPhone 12 mini")
    }
  }
#endif
