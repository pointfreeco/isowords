import DailyChallengeReports
import NIO
import ServerBootstrap

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let environment = try bootstrap(
  eventLoopGroup: eventLoopGroup
)
.run
.perform()
.unwrap()

_ = try sendDailyChallengeReports(
  database: environment.database,
  sns: environment.snsClient
)
.run
.perform()
.unwrap()

try environment.database.shutdown()  // todo: defer
  .run
  .perform()
  .unwrap()
