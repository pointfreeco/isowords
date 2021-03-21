import ComposableArchitecture
import DailyChallengeFeature
import LeaderboardFeature
import Overture
import SharedModels
import SwiftUI

var dailyChallengeAppStoreView: AnyView {
  let json = #"""
    {"results":[{"playerId":"00000000-0000-0000-0000-00000000772E","score":2327,"rank":1,"outOf":33,"isYourScore":false,"playerDisplayName":"stephencelis"},{"playerDisplayName":"mbrandonw","score":1696,"rank":2,"playerId":"00000000-0000-0000-0000-00000000621F","isYourScore":false,"outOf":33},{"playerDisplayName":"kmh2021","playerId":"00000000-0000-0000-0000-000000002B20","rank":3,"score":1655,"isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000F08B","score":1556,"rank":4,"outOf":33,"isYourScore":false,"playerDisplayName":"twernie"},{"playerId":"00000000-0000-0000-0000-000000008A46","score":1353,"rank":5,"outOf":33,"isYourScore":false,"playerDisplayName":"robsr 47"},{"playerId":"00000000-0000-0000-0000-000000007F93","score":1126,"rank":6,"outOf":33,"isYourScore":false,"playerDisplayName":"Call Me Yanny"},{"playerId":"00000000-0000-0000-0000-00000000A877","playerDisplayName":"chefnobody","score":968,"rank":7,"isYourScore":false,"outOf":33},{"playerDisplayName":"smartman 2000","score":960,"rank":8,"playerId":"00000000-0000-0000-0000-0000000072AB","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000A4BB","outOf":33,"rank":9,"score":943,"isYourScore":false,"playerDisplayName":"lelandr"},{"playerId":"00000000-0000-0000-0000-0000000011AF","score":925,"rank":10,"isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-0000000050FA","score":907,"rank":11,"playerDisplayName":"myurieff","isYourScore":false,"outOf":33},{"outOf":33,"score":902,"rank":12,"playerId":"00000000-0000-0000-0000-0000000065B2","isYourScore":false,"playerDisplayName":"Wyntermutex"},{"playerId":"00000000-0000-0000-0000-00000000E878","outOf":33,"score":760,"rank":13,"isYourScore":false,"playerDisplayName":"simme"},{"playerId":"00000000-0000-0000-0000-00000000887B","score":724,"rank":14,"isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000C173","score":723,"playerDisplayName":"junebash","rank":15,"isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000E245","score":721,"rank":16,"playerDisplayName":"ryanbooker","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000CC5A","score":678,"rank":17,"playerDisplayName":"_maloneh","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-000000003021","score":670,"playerDisplayName":"pearapps","rank":18,"isYourScore":false,"outOf":33},{"playerDisplayName":"Kevlario","score":615,"rank":19,"playerId":"00000000-0000-0000-0000-000000008956","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-000000007DC4","score":599,"rank":20,"playerDisplayName":"carohodges","isYourScore":false,"outOf":33},{"outOf":33,"score":540,"rank":21,"playerId":"00000000-0000-0000-0000-00000000018C","isYourScore":false,"playerDisplayName":"scibidoo"},{"outOf":33,"score":497,"playerId":"00000000-0000-0000-0000-00000000000C","rank":22,"isYourScore":false,"playerDisplayName":"LazyAugust"},{"playerId":"00000000-0000-0000-0000-000000003F2C","score":448,"rank":23,"isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-0000000063E2","score":447,"playerDisplayName":"oh_it's_daniel","rank":24,"isYourScore":false,"outOf":33},{"outOf":33,"score":438,"rank":25,"playerId":"00000000-0000-0000-0000-0000000074C2","isYourScore":false,"playerDisplayName":"jcc7nstwl6r4r"},{"outOf":33,"score":429,"rank":26,"playerId":"00000000-0000-0000-0000-00000000314F","isYourScore":false,"playerDisplayName":"mmatoszko"},{"playerId":"00000000-0000-0000-0000-00000000FF79","outOf":33,"score":420,"rank":27,"isYourScore":false,"playerDisplayName":"Connoljoff"},{"playerId":"00000000-0000-0000-0000-00000000925A","outOf":33,"rank":28,"score":412,"isYourScore":false,"playerDisplayName":"_machorro_"},{"playerId":"00000000-0000-0000-0000-00000000128D","score":357,"rank":29,"playerDisplayName":"mkuhnt","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-000000001BA5","score":284,"rank":30,"isYourScore":false,"outOf":33},{"playerDisplayName":"TheC0r3","score":208,"rank":31,"playerId":"00000000-0000-0000-0000-00000000E277","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-000000007907","score":194,"rank":32,"playerDisplayName":"satqgaevk9bwp","isYourScore":false,"outOf":33},{"playerId":"00000000-0000-0000-0000-00000000B3DF","outOf":33,"rank":33,"score":113,"isYourScore":false,"playerDisplayName":"blob"}]}
    """#
  let response = try! JSONDecoder()
    .decode(FetchDailyChallengeResultsResponse.self, from: Data(json.utf8))

  let view = DailyChallengeResultsView(
    store: Store<DailyChallengeResultsState, DailyChallengeResultsAction>(
      initialState: DailyChallengeResultsState(
        history: nil,
        leaderboardResults: .init(
          gameMode: .timed,
          isLoading: false,
          isTimeScopeMenuVisible: false,
          resultEnvelope: ResultEnvelope(response),
          timeScope: nil
        )
      ),
      reducer: .empty,
      environment: ()
    )
  )
  return AnyView(view)
}
