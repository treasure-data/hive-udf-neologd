#!/bin/bash

# The original script: https://github.com/kazuhira-r/kuromoji-with-mecab-neologd-buildscript

set -eu

SCRIPT_NAME=$0
KUROMOJI_NEOLOGD_BUILD_WORK_DIR=`pwd`

logging() {
    LABEL=$1
    LEVEL=$2
    MESSAGE=$3

    TIME=`date +"%Y-%m-%d %H:%M:%S"`

    echo "### [$TIME] [$LABEL] [$LEVEL] $MESSAGE"
}

usage() {
    cat <<EOF
Usage: ${SCRIPT_NAME} [options...]
  options:
    -d ... specify NEologd version date. (format: YYYYMMDD, default: latest dictionary on the master branch)
    -h ... help.
EOF
}

## mecab-ipadic-NEologd Target Tag
MECAB_IPADIC_NEOLOGD_TAG=master

while getopts c:d:h OPTION
do
    case $OPTION in
        d)
            yyyymmdd="^[0-9]{8}$"
            if [[ ! ${OPTARG} =~ $yyyymmdd ]]; then
              usage
              exit 1
            fi
            MECAB_IPADIC_NEOLOGD_TAG=${OPTARG:0:4}-${OPTARG:4:2}-${OPTARG:6};;
        h)
            usage
            exit 0;;
        \?)
            usage
            exit 1;;
    esac
done

## MeCab
MECAB_VERSION=mecab-0.996
MECAB_INSTALL_DIR=${KUROMOJI_NEOLOGD_BUILD_WORK_DIR}/mecab

## mecab-ipadic-NEologd
MAX_BASEFORM_LENGTH=15

## Lucene Target Tag
LUCENE_VERSION=5.5.5
DEFAULT_LUCENE_VERSION_TAG=
LUCENE_VERSION_TAG=releases/lucene-solr/${LUCENE_VERSION}

## Kuromoji build max heapsize
KUROMOJI_BUILD_MAX_HEAPSIZE=5g

## generated JAR file output directory
JAR_FILE_OUTPUT_DIRECTORY=.

## Source Package
DEFAULT_KUROMOJI_PACKAGE=org.apache.lucene.analysis.ja
REDEFINED_KUROMOJI_PACKAGE=org.apache.lucene.analysis.ja.neologd

logging main INFO 'START.'

if [ ! -d ${JAR_FILE_OUTPUT_DIRECTORY} ]; then
    logging pre-check ERROR "directory[${JAR_FILE_OUTPUT_DIRECTORY}], not exits."
    exit 1
fi

if [ ! `which mecab` ]; then
    if [ ! -e ${MECAB_INSTALL_DIR}/bin/mecab ]; then
        logging mecab INFO 'MeCab Install Local.'

        if [ ! -e ${MECAB_VERSION}.tar.gz ]; then
            curl 'https://drive.google.com/uc?export=download&id=0B4y35FiV1wh7cENtOXlicTFaRUE' -L -o ${MECAB_VERSION}.tar.gz
        fi
        tar -zxf ${MECAB_VERSION}.tar.gz
        cd ${MECAB_VERSION}

        if [ ! -e ${MECAB_INSTALL_DIR} ]; then
            mkdir -p ${MECAB_INSTALL_DIR}
        fi

        ./configure --prefix=${MECAB_INSTALL_DIR}
        make
        make install
    fi

    PATH=${MECAB_INSTALL_DIR}/bin:${PATH}
fi

cd ${KUROMOJI_NEOLOGD_BUILD_WORK_DIR}

logging mecab-ipadic-NEologd INFO 'Download mecab-ipadic-NEologd.'

if [ ! -e mecab-ipadic-neologd ]; then
    git clone https://github.com/neologd/mecab-ipadic-neologd.git
else
    cd mecab-ipadic-neologd

    if [ -d build ]; then
        rm -rf build
    fi

    git checkout master
    git fetch origin
    git reset --hard origin/master
    git pull --tags
    cd ..
fi

cd mecab-ipadic-neologd

if [ "${MECAB_IPADIC_NEOLOGD_TAG}" != "master" ]; then
    logging mecab-ipadic_NEologd INFO "Use dictionary published on the nearest date after ${MECAB_IPADIC_NEOLOGD_TAG} (inclusive)"
    NEAREST_COMMIT_DATE=`git log --pretty=format:%cd --date=short --after=${MECAB_IPADIC_NEOLOGD_TAG} --reverse | head -n 1`
    MECAB_IPADIC_NEOLOGD_TAG=`git log -1 --pretty=format:%H --after="${NEAREST_COMMIT_DATE}T00:00:00Z" --until="${NEAREST_COMMIT_DATE}T23:59:59Z"`

    if [ -z "$MECAB_IPADIC_NEOLOGD_TAG" ]; then
        logging mecab-ipadic_NEologd ERROR "NEologd version date specified by the '-d' option is invalid."
        exit 1
    fi

    MECAB_IPADIC_NEOLOGD_MASTER_COMMIT_HASH=`git rev-parse master`
    if [ "${MECAB_IPADIC_NEOLOGD_TAG}" == "${MECAB_IPADIC_NEOLOGD_MASTER_COMMIT_HASH}" ]; then
        logging mecab-ipadic_NEologd INFO "NEologd version date specified by the '-d' option corresponds to the master branch."
    else
        git checkout ${MECAB_IPADIC_NEOLOGD_TAG}

        if [ $? -ne 0 ]; then
            logging mecab-ipadic-NEologd ERROR "git checkout[${MECAB_IPADIC_NEOLOGD_TAG}] failed. Please re-run after execute 'rm -f mecab-ipadic-neologd'"
            exit 1
        fi

        rm -f seed/mecab-user-dict-seed.*

        # get the seed file
        SEED_COMMIT_HASH=`cat ChangeLog | grep -m 1 'commit: ' | perl -wp -e 's!^.*/([0-9a-z]+).*$!$1!'`
        SEED_FILENAME=`cat ChangeLog | grep -m 1 'seed/' | perl -wp -e 's!^.*seed/(.+\.csv\.xz).*$!$1!'`
        if [ -z "$SEED_COMMIT_HASH" -o -z "$SEED_FILENAME" ]; then
            logging mecab-ipadic_NEologd ERROR "NEologd changelog cannot be parsed, and hence seed file name and its commit hash cannot be found."
            exit 1
        fi
        SEED_DOWNLOAD_URL=https://github.com/neologd/mecab-ipadic-neologd/raw/${SEED_COMMIT_HASH}/seed/${SEED_FILENAME}

        logging mecab-ipadic_NEologd INFO "Download mecab-user-dict-seed file: ${SEED_DOWNLOAD_URL}"
        wget $SEED_DOWNLOAD_URL -O seed/$SEED_FILENAME
    fi
fi

libexec/make-mecab-ipadic-neologd.sh -L ${MAX_BASEFORM_LENGTH}

DIR=`pwd`

NEOLOGD_BUILD_DIR=`find ${DIR}/build/mecab-ipadic-* -maxdepth 1 -type d`
NEOLOGD_DIRNAME=`basename ${NEOLOGD_BUILD_DIR}`
NEOLOGD_VERSION_DATE=`echo ${NEOLOGD_DIRNAME} | perl -wp -e 's!.+-(\d+)!$1!'`

cd ${KUROMOJI_NEOLOGD_BUILD_WORK_DIR}

logging lucene INFO 'Lucene Repository Clone.'
if [ ! -e lucene-solr ]; then
    git clone --branch ${LUCENE_VERSION_TAG} --depth 1 https://github.com/apache/lucene-solr.git
fi
cd lucene-solr

if [ "$(git symbolic-ref -q --short HEAD || git describe --tags)" != "${LUCENE_VERSION_TAG}" ]; then
    cd ..
    rm -rf lucene-solr
    git clone --branch ${LUCENE_VERSION_TAG} --depth 1 https://github.com/apache/lucene-solr.git
    cd lucene-solr
fi

git checkout ${LUCENE_VERSION_TAG}
git reset --hard ${LUCENE_VERSION_TAG}
git status -s | grep '^?' | perl -wn -e 's!^\?+ ([^ ]+)!git clean -df $1!; system("$_")'
ant clean

LUCENE_SRC_DIR=`pwd`

if [ $? -ne 0 ]; then
    logging lucene ERROR "git checkout[${LUCENE_VERSION_TAG}] failed. Please re-run after execute 'rm -f lucene-solr'"
    exit 1
fi

cd lucene
ant ivy-bootstrap

cd analysis/kuromoji
KUROMOJI_SRC_DIR=`pwd`

git checkout build.xml

logging lucene INFO 'Build Lucene Kuromoji, with mecab-ipadic-NEologd.'
mkdir -p ${LUCENE_SRC_DIR}/lucene/build/analysis/kuromoji
cp -Rp ${NEOLOGD_BUILD_DIR} ${LUCENE_SRC_DIR}/lucene/build/analysis/kuromoji

if [ "${LUCENE_VERSION_TAG}" = "releases/lucene-solr/5.0.0" ]; then
    loging lucene INFO 'avoid https://issues.apache.org/jira/browse/LUCENE-6368'
    perl -wp -i -e 's!^    try \(OutputStream os = Files.newOutputStream\(path\)\) {!    try (OutputStream os = new BufferedOutputStream(Files.newOutputStream(path))) {!' ${LUCENE_SRC_DIR}/lucene/core/src/java/org/apache/lucene/util/fst/FST.java
    perl -wp -i -e 's!^      save\(new OutputStreamDataOutput\(new BufferedOutputStream\(os\)\)\);!      save(new OutputStreamDataOutput(os));!' ${LUCENE_SRC_DIR}/lucene/core/src/java/org/apache/lucene/util/fst/FST.java
fi

if [ -e ${LUCENE_SRC_DIR}/lucene/version.properties ]; then
    perl -wp -i -e "s!^version.suffix=(.+)!version.suffix=${NEOLOGD_VERSION_DATE}-SNAPSHOT!" ${LUCENE_SRC_DIR}/lucene/version.properties
fi
perl -wp -i -e "s!\"dev.version.suffix\" value=\"SNAPSHOT\"!\"dev.version.suffix\" value=\"${NEOLOGD_VERSION_DATE}-SNAPSHOT\"!" ${LUCENE_SRC_DIR}/lucene/common-build.xml
perl -wp -i -e 's!<project name="analyzers-kuromoji"!<project name="analyzers-kuromoji-ipadic-neologd"!' build.xml
perl -wp -i -e 's!maxmemory="[^"]+"!maxmemory="'${KUROMOJI_BUILD_MAX_HEAPSIZE}'"!' build.xml

if [ "${REDEFINED_KUROMOJI_PACKAGE}" != "${DEFAULT_KUROMOJI_PACKAGE}" ]; then
    logging lucene INFO "redefine package [${DEFAULT_KUROMOJI_PACKAGE}] => [${REDEFINED_KUROMOJI_PACKAGE}]."

    ORIGINAL_SRC_DIR=`echo ${DEFAULT_KUROMOJI_PACKAGE} | perl -wp -e 's!\.!/!g'`
    NEW_SRC_DIR=`echo ${REDEFINED_KUROMOJI_PACKAGE} | perl -wp -e 's!\.!/!g'`

    test -d ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR} && rm -rf ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR}
    mkdir -p ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR}
    find ${KUROMOJI_SRC_DIR}/src/java/${ORIGINAL_SRC_DIR} -mindepth 1 -maxdepth 1 -not -path ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR} | xargs -I{} mv {} ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR}
    find ${KUROMOJI_SRC_DIR}/src/java/${NEW_SRC_DIR} -type f | xargs perl -wp -i -e "s!${DEFAULT_KUROMOJI_PACKAGE//./\\.}!${REDEFINED_KUROMOJI_PACKAGE}!g"

    test -d ${KUROMOJI_SRC_DIR}/src/resources/${NEW_SRC_DIR} && rm -rf ${KUROMOJI_SRC_DIR}/src/resources/${NEW_SRC_DIR}
    mkdir -p ${KUROMOJI_SRC_DIR}/src/resources/${NEW_SRC_DIR}
    find ${KUROMOJI_SRC_DIR}/src/resources/${ORIGINAL_SRC_DIR} -mindepth 1 -maxdepth 1 -not -path ${KUROMOJI_SRC_DIR}/src/resources/${NEW_SRC_DIR} | xargs -I{} mv {} ${KUROMOJI_SRC_DIR}/src/resources/${NEW_SRC_DIR}

    test -d ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR} && rm -rf ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR}
    mkdir -p ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR}
    find ${KUROMOJI_SRC_DIR}/src/tools/java/${ORIGINAL_SRC_DIR} -mindepth 1 -maxdepth 1 -not -path ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR} | xargs -I{} mv {} ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR}
    find ${KUROMOJI_SRC_DIR}/src/tools/java/${NEW_SRC_DIR} -type f | xargs perl -wp -i -e "s!${DEFAULT_KUROMOJI_PACKAGE//./\\.}!${REDEFINED_KUROMOJI_PACKAGE}!g"

    perl -wp -i -e "s!${ORIGINAL_SRC_DIR}!${NEW_SRC_DIR}!g" build.xml
    perl -wp -i -e "s!${DEFAULT_KUROMOJI_PACKAGE//./\\.}!${REDEFINED_KUROMOJI_PACKAGE}!g" build.xml
fi

ant -Dipadic.version=${NEOLOGD_DIRNAME} -Ddict.encoding=utf-8 regenerate
if [ $? -ne 0 ]; then
    logging lucene ERROR 'Dictionary Build Fail.'
    exit 1
fi

ant jar-core
if [ $? -ne 0 ]; then
    logging lucene ERROR 'Kuromoji Build Fail.'
    exit 1
fi

cd ${KUROMOJI_NEOLOGD_BUILD_WORK_DIR}

logging udf INFO 'Package hive-udf-neologd'

mvn versions:set -f lucene-analyzers-kuromoji-neologd.xml -DnewVersion=${LUCENE_VERSION} -DgenerateBackupPoms=false
mvn versions:set-property -Dproperty=lucene.version -DnewVersion=${LUCENE_VERSION} -DgenerateBackupPoms=false
git commit --dry-run lucene-analyzers-kuromoji-neologd.xml pom.xml && git commit lucene-analyzers-kuromoji-neologd.xml pom.xml -m "Set Lucene version to "${LUCENE_VERSION}

KUROMOJI_SNAPSHOT_JAR_FILENAME=`ls -1 ${LUCENE_SRC_DIR}/lucene/build/analysis/kuromoji/lucene-analyzers-kuromoji*`
mvn install:install-file \
    -Dfile=${KUROMOJI_SNAPSHOT_JAR_FILENAME} \
    -DpomFile=lucene-analyzers-kuromoji-neologd.xml

UDF_VERSION=`cat VERSION`
mvn versions:set -DnewVersion=${UDF_VERSION}-${NEOLOGD_VERSION_DATE} -DgenerateBackupPoms=false
echo ${NEOLOGD_VERSION_DATE} > NEOLOGD_VERSION_DATE
git commit --dry-run VERSION NEOLOGD_VERSION_DATE pom.xml && git commit VERSION NEOLOGD_VERSION_DATE pom.xml -m "Update version to ${UDF_VERSION}-${NEOLOGD_VERSION_DATE}"

mvn clean install

logging main INFO 'END.'
