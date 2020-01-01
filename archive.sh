#!/bin/bash

#Archive unused Files
#--Format
#--    SCRIPT_NAME [archive|a] <file-1> <file-2> ... <file-n>
#--    SCRIPT_NAME [list|l]    [<start-time> [<end-time>]]
#--    SCRIPT_NAME [restore|r] <file-hash> <destination-file>
#--    SCRIPT_NAME [reindex|i]

export SCRIPT_FILE=`echo $0|sed 's/.*\/\(.*$\)/\1/'`
if [ -z $ARCHIVE_DIR ]; then
    #ARCHIVE_DIR=$HOME/ARCHIVE_DIR
    echo "Error : No ARCHIVE_DIR variable set"
    exit 1
fi

if [ ! -d $ARCHIVE_DIR ]; then
    mkdir --parent $ARCHIVE_DIR
    if [ $? -ne 0 ]; then
        printf "Error : Unable to Create Directory %s\n" $ARCHIVE_DIR
        exit 1
    fi
fi

archive()
{
    while [ $# -ne 0 ]; do
        if [ ! -e $1 ]; then
            shift
            continue;
        fi

        #if [ ! -d $ARCHIVE_DIR ]; then
        #    mkdir $ARCHIVE_DIR
        #fi

        JUST_FILE_NAME=`basename $1`
        DATE_STAMP=`date +%s`
        RANDOM_FILE_NAME=`mktemp -u | sed 's/.*\(tmp\..*\)/\1/'`
        NAME_HASH=`echo $1.$RANDOM_FILE_NAME | md5sum | cut -d " " -f1`
        echo Archiving $1...
        if [ -d $1 ]; then
            TEMP_FILE=`mktemp`
            zip -rq0 $TEMP_FILE.zip $1
            mv $TEMP_FILE.zip $ARCHIVE_DIR/$NAME_HASH
            FORMAT=ZIP
        else
            cp $1 $ARCHIVE_DIR/$NAME_HASH
            FORMAT=REG
        fi
        FILE_HASH=`md5sum $ARCHIVE_DIR/$NAME_HASH | cut -d " " -f1`
        echo $DATE_STAMP:$NAME_HASH:$FILE_HASH:$FORMAT:$JUST_FILE_NAME >> $ARCHIVE_DIR/index.txt
        shift
    done
}

list()
{
    if [ ! -f $ARCHIVE_DIR/index.txt ]; then
        exit 0
    fi

    if [ $# -eq 1 ]; then
        START_TIME=$1
    else
        START_TIME=0
    fi

    if [ $# -eq 2 ]; then
        END_TIME=$2
    else
        END_TIME=`date +%s`
    fi

    while read line; do
        TIMESTAMP=`echo $line | cut -d ":" -f1 `
        NAME_HASH=`echo $line | cut -d ":" -f2 `
        FILE_HASH=`echo $line | cut -d ":" -f3 `
        FORMAT=`echo $line    | cut -d ":" -f4 `
        FILE_NAME=`echo $line | cut -d ":" -f5 `
        if [ $TIMESTAMP -ge $START_TIME ] && [ $TIMESTAMP -le $END_TIME ]; then
            echo `date -d @$TIMESTAMP` : $NAME_HASH : $FILE_NAME
        fi
    done < $ARCHIVE_DIR/index.txt
}

restore()
{
    if [ $# -lt 2 ]; then
        exit 1
    fi
    if [ ! -f $ARCHIVE_DIR/index.txt ]; then
        exit 0
    fi
    while read line; do
        TIMESTAMP=`echo $line | cut -d ":" -f1 `
        NAME_HASH=`echo $line | cut -d ":" -f2 `
        FILE_HASH=`echo $line | cut -d ":" -f3 `
        FORMAT=`echo $line    | cut -d ":" -f4 `
        FILE_NAME=`echo $line | cut -d ":" -f5 `
        if [ $NAME_HASH == $1 ]; then
            if [ $FORMAT == ZIP ]; then
                unzip -q $ARCHIVE_DIR/$NAME_HASH -d $2
            else
                cp -v $ARCHIVE_DIR/$NAME_HASH $2
            fi
            break
        fi
    done < $ARCHIVE_DIR/index.txt
}

reindex()
{
    if [ ! -f $ARCHIVE_DIR/index.txt ]; then
        exit 0
    fi
    TEMP_FILE=`mktemp`
    while read line; do
        TIMESTAMP=`echo $line | cut -d ":" -f1 `
        NAME_HASH=`echo $line | cut -d ":" -f2 `
        FILE_HASH=`echo $line | cut -d ":" -f3 `
        FORMAT=`echo $line    | cut -d ":" -f4 `
        FILE_NAME=`echo $line | cut -d ":" -f5 `
        if [ -f $ARCHIVE_DIR/$NAME_HASH ]; then

            MD5SUM=`md5sum $ARCHIVE_DIR/$NAME_HASH | cut -d " " -f1`
            if [ $MD5SUM == $FILE_HASH ]; then
                echo "$line" >> "$TEMP_FILE"
            else
                rm -rfv $ARCHIVE_DIR/$NAME_HASH
            fi
        fi
    done < $ARCHIVE_DIR/index.txt
    mv $TEMP_FILE $ARCHIVE_DIR/index.txt
}

print_help()
{
    grep "^#\-\-" $0 | cut -c4- | sed 's/SCRIPT_NAME/'"$SCRIPT_FILE"'/'
}

if [ $# -ge 1 ]; then
    COMMAND=$1
    shift
else
    print_help
    exit 1
fi
case "$COMMAND" in
    "archive"|"a")
        archive $*
        ;;
    "list"|"l")
        list $*
        ;;
    "restore"|"r")
        restore $*
        ;;
    "index"|"i")
        reindex
        ;;
    *)
        print_help
esac
