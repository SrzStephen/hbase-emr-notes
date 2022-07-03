sudo yum install -y java-1.8.0-openjdk-headless.x86_64 go
sudo yum install -y https://github.com/OpenTSDB/opentsdb/releases/download/v2.4.1/opentsdb-2.4.1-1-20210902183110-root.noarch.rpm
wget https://dlcdn.apache.org/hbase/2.4.13/hbase-2.4.13-bin.tar.gz
tar -xf hbase-2.4.13-bin.tar.gz
export HBASE_HOME=/home/ec2-user/hbase-2.4.13
export JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk/
export SALT_WIDTH=1
export MASTER_NODE=''
export PUSH_RATE=2000
rm /home/ec2-user/hbase-2.4.13/conf/hbase-site.xml
cat > /home/ec2-user/hbase-2.4.13/conf/hbase-site.xml <<EOF
<configuration>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>${MASTER_NODE}</value>
  </property>
</configuration>
EOF
rm /etc/opentsdb/opentsdb.conf
cat > /etc/opentsdb/opentsdb.conf <<EOF
tsd.network.port = 4242
tsd.http.staticroot = /usr/share/opentsdb/static/
tsd.http.cachedir = /tmp/opentsdb
tsd.core.plugin_path = /usr/share/opentsdb/plugins
tsd.core.auto_create_metrics = true
tsd.storage.hbase.zk_quorum = ${MASTER_NODE}
tsd.storage.salt.width = ${SALT_WIDTH}
# This only comes into effect if salt.width > 0
tsd.storage.salt.buckets = 4
EOF
cat > hbase_scripts.sh <<EOF
exec "${HBASE_HOME}/bin/hbase" shell <<EOL
create 'tsdb-uid',
  {NAME => 'id', COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'},
  {NAME => 'name', COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'}
create 'tsdb-tree',
{NAME => 't', VERSIONS => 1, COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'}
create 'tsdb-meta',
{NAME => 't', VERSIONS => 1, COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'}
EOL
EOF
chmod +x hbase_scripts.sh
./hbase_scripts.sh

cat > hbase_create_main.sh <<EOF
if [[ ${SALT_WIDTH} == 1 ]]; then # Create Data table with the option to split
exec "${HBASE_HOME}/bin/hbase" shell <<EOL
create 'tsdb',
  {NAME => 't', VERSIONS => 1, COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'},
  SPLITS=>['\x00\x00\x01', '\x00\x00\x02','\x00\x00\x03']
EOL
else
exec "${HBASE_HOME}/bin/hbase" shell <<EOL
create 'tsdb',
  {NAME => 't', VERSIONS => 1, COMPRESSION => 'LZO', BLOOMFILTER => 'ROW', DATA_BLOCK_ENCODING => 'DIFF'}
EOL
fi
EOF
chmod +x hbase_create_main.sh
./hbase_create_main.sh
sudo /usr/share/opentsdb/etc/init.d/opentsdb start
go get github.com/staticmukesh/opentsdb-load-generator
${HOME}/go/bin/opentsdb-load-generator -rate ${PUSH_RATE} -conn 10