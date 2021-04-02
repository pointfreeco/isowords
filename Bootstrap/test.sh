#!/bin/sh
apt-get --fix-missing update
apt-get install -y \
  cmake libpq-dev libsqlite3-dev libssl-dev libz-dev openssl postgresql sudo
service postgresql start
sudo -u postgres createuser --superuser isowords
sudo -u postgres psql -c "ALTER USER isowords PASSWORD 'isowords';"
sudo -u postgres createdb --owner isowords isowords_test
TEST_SERVER=1 swift test --enable-test-discovery || exit $?
swift build \
  --configuration=release \
  --enable-test-discovery \
  --product daily-challenge-reports \
  -Xswiftc -g \
  && swift build \
  --configuration=release \
  --enable-test-discovery \
  --product runner \
  -Xswiftc -g \
  && swift build \
  --configuration=release \
  --enable-test-discovery \
  --product server \
  -Xswiftc -g
