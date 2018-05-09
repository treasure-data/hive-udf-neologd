Hive Japanese NLP UDFs with NEologd
===

This package extends [Hivemall](https://github.com/apache/incubator-hivemall)'s Japanese NLP capability by utilizing [NEologd](https://github.com/neologd/mecab-ipadic-neologd).

## Usage

Get and run build script from [kazuhira-r/kuromoji-with-mecab-neologd-buildscript](https://github.com/kazuhira-r/kuromoji-with-mecab-neologd-buildscript):

```sh
./build-lucene-kuromoji-with-mecab-ipadic-neologd.sh -L releases/lucene-solr/5.3.1 -p org.apache.lucene.analysis.ja.neologd
```

Install the custom Japanese tokenizer to local Maven repository:

```sh
mvn install:install-file \
    -Dfile=lucene-analyzers-kuromoji-ipadic-neologd-5.3.1-20180507.jar \
    -DpomFile=lucene-analyzers-kuromoji-neologd.pom
```

Build Hive UDF:

```sh
mvn clean install
```

Test on Hive:

```sql
add jar hive-udf-neologd-0.1.0-20180503.jar;
create temporary function tokenize_ja_neologd as 'hivemall.nlp.tokenizer.KuromojiNEologdUDF';
select tokenize_ja_neologd('10日放送の「中居正広のミになる図書館」（テレビ朝日系）で、SMAPの中居正広が、篠原信一の過去の勘違いを明かす一幕があった。');
```
