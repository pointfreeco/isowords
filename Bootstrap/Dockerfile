FROM swift:5.5 as build

RUN apt-get --fix-missing update
RUN apt-get install -y cmake libpq-dev libssl-dev libz-dev openssl python
RUN apt-get install --no-install-recommends libsqlite3-dev

WORKDIR /build

COPY Package.swift .
COPY Sources ./Sources
COPY Tests ./Tests

RUN swift build \
  --configuration release \
  --enable-test-discovery \
  --product daily-challenge-reports \
  -Xswiftc -g \
  && swift build \
  --configuration release \
  --enable-test-discovery \
  --product runner \
  -Xswiftc -g \
  && swift build \
  --configuration release \
  --enable-test-discovery \
  --product server \
  -Xswiftc -g

FROM swift:5.5-slim

RUN apt-get --fix-missing update
RUN apt-get install -y libpq-dev libsqlite3-dev libssl-dev libz-dev openssl python

WORKDIR /run

COPY --from=build /build/.build/release /run

CMD ./server
