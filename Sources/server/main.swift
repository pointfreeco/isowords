import HttpPipeline
import NIO
import ServerBootstrap
import SiteMiddleware

#if DEBUG
  let numberOfThreads = 1
#else
  let numberOfThreads = System.coreCount
#endif
let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: numberOfThreads)

let environment = try bootstrap(
  eventLoopGroup: eventLoopGroup
)
.run
.perform()
.unwrap()

run(
  siteMiddleware(environment: environment),
  on: Int(environment.envVars.port)!,
  eventLoopGroup: eventLoopGroup,
  gzip: true,
  baseUrl: environment.envVars.baseUrl
)

try environment.database.shutdown()
  .run
  .perform()
  .unwrap()
