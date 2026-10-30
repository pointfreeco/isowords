import ComposableArchitecture
import Dependencies
import SharedModels
import SwiftUI

@Feature
public struct WordSubmitButtonFeature {
  public struct State {
    public var isSelectedWordValid: Bool
    public let isTurnBasedMatch: Bool
    public let isYourTurn: Bool
    public var wordSubmitButton: ButtonState

    public init(
      isSelectedWordValid: Bool,
      isTurnBasedMatch: Bool,
      isYourTurn: Bool,
      wordSubmitButton: ButtonState
    ) {
      self.isSelectedWordValid = isSelectedWordValid
      self.isTurnBasedMatch = isTurnBasedMatch
      self.isYourTurn = isYourTurn
      self.wordSubmitButton = wordSubmitButton
    }
  }

  public struct ButtonState: Equatable {
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

  public enum Action {
    case backgroundTapped
    case reactionButtonTapped(Move.Reaction)
    case submitButtonPressed
    case submitButtonReleased
    case submitButtonTapped
  }

  public enum ConfirmSubmit: FeatureEventKey {
    public typealias Value = Move.Reaction?
  }

  @Dependency(\.feedbackGenerator) var feedbackGenerator
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.audioPlayer.play) var playSound

  @StoreTaskID var submitButtonPressedDelay

  public init() {}

  public var body: some Feature {
    Update { state, action in
      guard state.isYourTurn
      else { return }

      switch action {
      case .backgroundTapped:
        state.wordSubmitButton.areReactionsOpen = false
        store.addTask { await self.playSound(.uiSfxEmojiClose) }

      case let .reactionButtonTapped(reaction):
        state.wordSubmitButton.areReactionsOpen = false
        store.addTask {
          await self.feedbackGenerator.selectionChanged()
          await self.playSound(.uiSfxEmojiSend)
          try store.post(key: ConfirmSubmit.self, value: reaction)
        }

      case .submitButtonPressed:
        guard state.isTurnBasedMatch
        else { return }

        if state.wordSubmitButton.areReactionsOpen {
          state.wordSubmitButton.isClosing = true
        }
        state.wordSubmitButton.areReactionsOpen = false
        state.wordSubmitButton.isSubmitButtonPressed = true

        let isClosing = state.wordSubmitButton.isClosing
        store.addTask(id: self.submitButtonPressedDelay) {
          await self.feedbackGenerator.selectionChanged()
          if isClosing {
            await self.playSound(.uiSfxEmojiClose)
          }
          try await self.mainQueue.sleep(for: 0.5)
          guard store.isYourTurn else { return }
          try store.modify { $0.wordSubmitButton.areReactionsOpen = true }
          await self.feedbackGenerator.selectionChanged()
          await self.playSound(.uiSfxEmojiOpen)
        }

      case .submitButtonReleased:
        guard state.isTurnBasedMatch
        else { return }

        let wasClosing = state.wordSubmitButton.isClosing
        state.wordSubmitButton.isClosing = false
        state.wordSubmitButton.isSubmitButtonPressed = false

        let areReactionsOpen = state.wordSubmitButton.areReactionsOpen
        store.addTask {
          self.submitButtonPressedDelay.cancel()
          guard !wasClosing && !areReactionsOpen
          else { return }
          try store.post(key: ConfirmSubmit.self, value: nil)
        }

      case .submitButtonTapped:
        guard !state.isTurnBasedMatch
        else { return }

        store.addTask {
          try store.post(key: ConfirmSubmit.self, value: nil)
        }
      }
    }
  }
}

public struct WordSubmitButton: View {
  @Environment(\.deviceState) var deviceState
  let store: StoreOf<WordSubmitButtonFeature>
  @State var isTouchDown = false

  public init(store: StoreOf<WordSubmitButtonFeature>) {
    self.store = store
  }

  public var body: some View {
    ZStack(alignment: Alignment(horizontal: .center, vertical: .bottom)) {
      if store.wordSubmitButton.areReactionsOpen {
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
          ReactionsView(store: store)

          Button {
            withAnimation { _ = store.send(.submitButtonTapped) }
          } label: {
            Group {
              if !store.wordSubmitButton.areReactionsOpen {
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
            .opacity(store.isSelectedWordValid ? 1 : 0.5)
            .font(.system(size: self.deviceState.isPad ? 40 : 30))
            .adaptivePadding([.all], .grid(4))
            // NB: Expand the tappable radius of the button.
            .background(Color.black.opacity(0.0001))
          }
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { touch in
                if !self.isTouchDown {
                  withAnimation { _ = store.send(.submitButtonPressed) }
                }
                self.isTouchDown = true
              }
              .onEnded { _ in
                withAnimation { _ = store.send(.submitButtonReleased) }
                self.isTouchDown = false
              }
          )
        }
        .padding()
      }

    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      if store.wordSubmitButton.areReactionsOpen {
        Color.isowordsBlack.opacity(0.4)
      }
    }
    .animation(.default, value: store.wordSubmitButton.areReactionsOpen)
    .onTapGesture { withAnimation { _ = store.send(.backgroundTapped) } }
  }
}

struct ReactionsView: View {
  let store: StoreOf<WordSubmitButtonFeature>

  var body: some View {
    ForEach(Array(store.wordSubmitButton.favoriteReactions.enumerated()), id: \.offset) { idx, reaction in
      let offset = self.offset(index: idx)

      Button {
        withAnimation { _ = store.send(.reactionButtonTapped(reaction)) }
      } label: {
        Text(reaction.rawValue)
          .font(.system(size: 32))
          .padding()
      }
      .background(Color.white.opacity(0.5))
      .clipShape(Circle())
      .rotationEffect(.degrees(store.wordSubmitButton.areReactionsOpen ? -360 : 0))
      .opacity(store.wordSubmitButton.areReactionsOpen ? 1 : 0)
      .offset(x: offset.x, y: offset.y)
      .animation(
        .default.delay(Double(idx) / Double(store.wordSubmitButton.favoriteReactions.count * 10)),
        value: store.wordSubmitButton.areReactionsOpen
      )
    }
  }

  func offset(index: Int) -> CGPoint {
    let angle: CGFloat =
      CGFloat.pi / CGFloat(store.wordSubmitButton.favoriteReactions.count - 1) * CGFloat(index) + .pi

    return .init(
      x: store.wordSubmitButton.areReactionsOpen ? cos(angle) * 130 : 0,
      y: store.wordSubmitButton.areReactionsOpen ? sin(angle) * 130 : 0
    )
  }
}

#if DEBUG
  struct WordSubmitButton_Previews: PreviewProvider {
    static var previews: some View {
      NavigationView {
        WordSubmitButton(
          store: Store(
            initialState: WordSubmitButtonFeature.State(
              isSelectedWordValid: true,
              isTurnBasedMatch: true,
              isYourTurn: true,
              wordSubmitButton: WordSubmitButtonFeature.ButtonState()
            )
          ) {
            WordSubmitButtonFeature()
          }
        )
        .background(Color.blue)
        .navigationBarHidden(true)
      }
      .previewDevice("iPhone 12 mini")
    }
  }
#endif
