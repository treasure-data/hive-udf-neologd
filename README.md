Hive Japanese NLP UDFs with NEologd
===

[![Build Status](https://travis-ci.org/treasure-data/hive-udf-neologd.svg?branch=master)](https://travis-ci.org/treasure-data/hive-udf-neologd)

This package extends [Hivemall](https://github.com/apache/incubator-hivemall)'s Japanese NLP capability by utilizing [NEologd](https://github.com/neologd/mecab-ipadic-neologd).

Before getting started, build the latest version of **hivemall-all-{HIVEMALL_VERSION}.jar** as documented on [Hivemall installation guide](https://hivemall.incubator.apache.org/userguide/getting_started/installation.html).

## Usage

Run build script:

```sh
./build.sh
```

> The build script is modified version of [kazuhira-r/kuromoji-with-mecab-neologd-buildscript](https://github.com/kazuhira-r/kuromoji-with-mecab-neologd-buildscript).

Use the UDFs on Hive:

```sql
add jar hivemall-all-{HIVEMALL_VERSION}.jar; -- e.g., hivemall-all-0.5.1-incubating-SNAPSHOT.jar
add jar hive-udf-neologd-{VERSION}-{NEOLOGD_VERSION_DATE}.jar; -- e.g., hive-udf-neologd-0.1.0-20180524.jar;
create temporary function tokenize_ja_neologd as 'hivemall.nlp.tokenizer.KuromojiNEologdUDF';
select tokenize_ja_neologd();
-- ["{VERSION}-{NEOLOGD_VERSION_DATE}"]
select tokenize_ja_neologd('10日放送の「中居正広のミになる図書館」（テレビ朝日系）で、SMAPの中居正広が、篠原信一の過去の勘違いを明かす一幕があった。');
-- ["10日","放送","中居正広の身になる図書館","テレビ朝日","系","smap","中居正広","篠原信一","過去","勘違い","明かす","一幕"]
```
