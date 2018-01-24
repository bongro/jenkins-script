#!/bin/bash
#Created by bongor on 2017/12/12.
channels=$1
build_type=$2
svn_code=$3

APK_PATH='app/build/outputs/apk'
APK_TEMP_DIR='app/build/outputs/temp'
declare -a flavors
declare -a apks
declare -a version_code
declare -a version_name

# 初始化有生成apk的flavor
function initFlavors() {
    flavors=($(ls $1))
}

# 遍历出apk目录下的所有apk文件
function findApks() {
    for file in `ls $1`; do
        file_path="$1/$file"
        if [[ -f ${file_path} ]]; then
            if [[ ${file} =~ ".apk" ]]; then
                apks=(${apks[*]} ${file_path})
            fi
        elif [[ -d ${file_path} ]]; then
            findApks "${file_path}"
        fi
    done
}

# 获取版本信息
function getVersionInfo() {
    for flavor in ${flavors[*]}; do
        echo ${flavor}
        flavor_version_code=`sed -n "/${flavor}.*{/,/}/p" app/build.gradle | grep -E -o 'versionCode.*[0-9]+' | grep -E -o '[0-9]+'`
        flavor_version_name=`sed -n "/${flavor}.*{/,/}/p" app/build.gradle | grep -E -o 'versionName.*[0-9]+' | grep -E -o '[0-9|.]+'`
        version_code=(${version_code[*]} ${flavor_version_code})
        version_name=(${version_name[*]} ${flavor_version_name})
    done
}

# 生成渠道apk
function generateChannelApk() {
    OLD_IFS="$IFS"
    IFS=";"
    arr=(${channels})
    IFS="$OLD_IFS"
    mkdir ${APK_TEMP_DIR}
    for((i=0;i<${#flavors[*]};i++)); do
        if [ ${flavors[$i]} == "news" ]; then
            flavor_project_name='GONews'
        elif [ ${flavors[$i]} == "video" ]; then
            flavor_project_name='FunnyVideo'
        fi

        for channel in ${arr[*]}; do
            apkFileName="${flavor_project_name}-vc${version_code[$i]}-vn${version_name[$i]}-${build_type}-${channel}-svn${svn_code}.apk"
            injectChannel "${apks[$i]}" "${channel}" "${apkFileName}"
            buildLog $? ${apkFileName}
        done
    done
}

# 渠道注入
function injectChannel() {
    apkFile=$1
    channel=$2
    apkName=$3
    #channel-injetor.jar 参数： 原apk文件、channel、输出目录、输出apk文件名
    java -jar channel-injector.jar ${apkFile} ${channel} ${APK_TEMP_DIR} ${apkName}
    buildLog $? "渠道号注入成功："${channel} "渠道号注入失败"${channel}
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

initFlavors ${APK_PATH}
findApks ${APK_PATH}
getVersionInfo
generateChannelApk


