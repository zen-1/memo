# data/

`./dify-bundle.sh export --lean data/dify_bundle_YYYYMMDD.tar.gz` で生成したバンドルを置く。

中身: `volumes/db/data` `volumes/app/storage`(pcap除く) `volumes/weaviate` `volumes/plugin_daemon`(cwd除く) `volumes/sandbox` `.env`

**DB がまるごと入っているので取り扱い注意。private リポジトリでのみ管理すること。**
