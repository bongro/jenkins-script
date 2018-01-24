#!/bin/bash
#Created by bongor on 2017/12/12.
apk_path=$1
ftp_dir=$2
channels=$3
build_type=$4
svn_code=$5

APK_TEMP_DIR=temp
VERSION_CODE=""
VERSION_NAME=""
ORIGIN_APK=apk
PROJECT_NAME=`echo ${ftp_dir} | cut -d '/' -f 5`

# 找到对应apk文件
function findOriginApk() {
    echo "遍历${apk_path}目录下的apk文件"
    for apk in $ `ls ${apk_path}`
    do
        if [[ ${apk} =~ ".apk" ]];
        then
            ORIGIN_APK=${apk_path}/${apk}
            break
        fi
    done
    if [[ ${ORIGIN_APK} != apk ]];
    then
        echo "找到apk文件：${ORIGIN_APK}"
    else
        echo "没有找到apk文件"
    fi
}

# 获取版本信息
function getVersionInfo() {
    VERSION_CODE=`grep -E -o 'versionCode.*[0-9]+' news/build.gradle | grep -E -o '[0-9]+'`
    VERSION_NAME=`grep -E -o 'versionName.*[0-9]+' news/build.gradle | grep -E -o '[0-9|.]+'`
    buildLog $? "versionCode:${VERSION_CODE} versionName:${VERSION_NAME}" "获取版本信息异常"
}

# 生成渠道apk
function generateChannelApk() {
    OLD_IFS="$IFS"
    IFS=";"
    arr=(${channels})
    IFS="$OLD_IFS"
    for channel in ${arr[*]}
    do
        apkFileName="${PROJECT_NAME}-vc${VERSION_CODE}-vn${VERSION_NAME}-${build_type}-${channel}-svn${svn_code}.apk"
        buildLog $? ${apkFileName}
        injectChannel ${channel} ${apkFileName}
    done
}

# 渠道注入
function injectChannel() {
    channel=$1
    apkName=$2
    #channel-injector.jar 参数： 原apk文件、channel、输出目录、输出apk文件名
    java -jar channel-injector.jar ${ORIGIN_APK} ${channel} ${apk_path} ${apkName}
    buildLog $? "渠道号注入成功："${channel} "渠道号注入失败"${channel}
}

# 删除临时文件
function deleteTempFiles() {
    rm -f ${ORIGIN_APK}
    buildLog $? "删除临时文件:${ORIGIN_APK}" "删除临时文件失败"
}

# 日志打印
function buildLog() {
    status=$1
    successMsg=$2
    errorMsg=$3
    if [[ ${status} -eq 0 ]]
    then
        echo ${successMsg}
    else
        echo ${errorMsg}
        exit -1
    fi
}

findOriginApk
getVersionInfo
generateChannelApk
deleteTempFiles


