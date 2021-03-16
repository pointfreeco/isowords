import NIO
import RunnerTasks
import ServerBootstrap

let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)

let environment = try bootstrap(
  eventLoopGroup: eventLoopGroup
)
.run
.perform()
.unwrap()

_ = try sendDailyChallengeEndsSoonNotifications(environment: environment)
  .run
  .perform()
  .unwrap()

try environment.database.shutdown()
  .run
  .perform()
  .unwrap()
