Hive Japanese NLP UDFs with NEologd
===

This package extends [Hivemall](https://github.com/apache/incubator-hivemall)'s Japanese NLP capability by utilizing [NEologd](https://github.com/neologd/mecab-ipadic-neologd).

Before getting started, get **hivemall-core-0.5.0-incubating** as documented on [Hivemall installation guide](https://hivemall.incubator.apache.org/userguide/getting_started/installation.html).

## Usage

Run build script:

```sh
./build.sh
```

> The build script is modified version of [kazuhira-r/kuromoji-with-mecab-neologd-buildscript](https://github.com/kazuhira-r/kuromoji-with-mecab-neologd-buildscript).

Set latest NEologd version date:

```sh
NEOLOGD_VERSION_DATE=`ls -1 lucene-analyzers-kuromoji*.jar | perl -wp -e 's!.+-(\d+).jar!$1!'`
mvn versions:set -DnewVersion=0.1.0-${NEOLOGD_VERSION_DATE} -DgenerateBackupPoms=false
git commit pom.xml -m "Bump NEologd version date to "${NEOLOGD_VERSION_DATE}
```

Install the custom Japanese tokenizer to local Maven repository:

```sh
mvn install:install-file \
    -Dfile=lucene-analyzers-kuromoji-ipadic-neologd-5.3.1-${NEOLOGD_VERSION_DATE}.jar \
    -DpomFile=lucene-analyzers-kuromoji-neologd.xml
```

Build Hive UDF:

```sh
mvn clean install
```

Test on Hive:

```sql
add jar hivemall-core-0.5.0-incubating.jar;
add jar hive-udf-neologd-0.1.0-{NEOLOGD_VERSION_DATE}.jar;
create temporary function tokenize_ja_neologd as 'hivemall.nlp.tokenizer.KuromojiNEologdUDF';
select tokenize_ja_neologd();
-- ["0.1.0-{NEOLOGD_VERSION_DATE}"]
select tokenize_ja_neologd('10日放送の「中居正広のミになる図書館」（テレビ朝日系）で、SMAPの中居正広が、篠原信一の過去の勘違いを明かす一幕があった。');
-- ["10日","放送","中居正広の身になる図書館","テレビ朝日","系","smap","中居正広","篠原信一","過去","勘違い","明かす","一幕"]
```
