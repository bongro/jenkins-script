#!/bin/bash
#@author zhangliang 2017
PACKAGE_DATE=`date +%Y-%m-%d%t%H:%M:%S`
apk_path=$1
ftp_dir=$2
channels=$3
apk_mode=$4
svn_code=$5

VERSION_NAME=1.0
VERSION_CODE=1
PACKAGE_SIZE=1

PROJECT_NAME=`echo ${ftp_dir} | cut -d '/' -f 5`
#构建邮件标题
MAIL_SUBJECT=${PROJECT_NAME}"_v"${VERSION_NAME}"_svn"${svn_code}"-"${channels}"包("${PACKAGE_DATE}")"
PROJECT_TITLE=${PROJECT_NAME}-${apk_mode}包

# 获取版本信息
VERSION_CODE=`grep -E -o 'versionCode.*[0-9]+' news/build.gradle | grep -E -o '[0-9]+'`
VERSION_NAME=`grep -E -o 'versionName.*[0-9]+' news/build.gradle | grep -E -o '[0-9|.]+'`
echo "versionName:${VERSION_NAME} versionCode${VERSION_CODE}"

# 读取打包后文件的大小
for apk in $ `ls ${apk_path}`
do
    if [[ ${apk} =~ ".apk" ]];
    then
        PACKAGE_SIZE=$(ls -l ${apk_path}/${apk} | cut -d " " -f 5)
        PACKAGE_SIZE=`expr "scale=2;${PACKAGE_SIZE}/(1024*1024)" |bc`
        echo "apk size : "${PACKAGE_SIZE}
        break
    fi
done

#读取svn日志，并写如到文件中
SVN_LOG_FILE=$(cat ./build-config.txt | grep SVN_LOG_FILE_NAME | cut -d "=" -f 2)
OLD_SVN_CODE=$(cat ./build-config.txt | grep SVN_CODE | cut -d "=" -f 2)
rm ./${SVN_LOG_FILE}
#尝试获取svn log
if [ "$OLD_SVN_CODE" ] ; then
    (svn log --revision ${OLD_SVN_CODE}:HEAD) >> ./${SVN_LOG_FILE}
fi
sed -i 's/SVN_CODE='${OLD_SVN_CODE}'/SVN_CODE='${svn_code}'/g' ./build-config.txt

# 获取渠道数组
OLD_IFS="$IFS"
IFS=";"
CHANNEL_ARRAY=(${channels})
IFS="$OLD_IFS"
#构建邮件中apk下载地址，预定义
CHANNEL_INFO=""
for channel in ${CHANNEL_ARRAY[*]}
do
    APK_NAME=${PROJECT_NAME}-vc${VERSION_CODE}-vn${VERSION_NAME}-${apk_mode}-${channel}-svn${svn_code}.apk
    APK_DOWNLOAD_ADDR="${ftp_dir}/${APK_NAME}"
    CHANNEL_INFO=" ${CHANNEL_INFO} <a href='"${APK_DOWNLOAD_ADDR}"'>${channel}</a>"
done

#生成邮件正文，将纯文本转换为html格式
#first part
MAIL_CONTENT="<html><head>
		<style>
table{border-right:1px solid #ccc;border-bottom:1px solid #ccc}
table td{border-left:1px solid #ccc;border-top:1px solid #ccc;padding-left:8px;padding-right:8px;}
*{font-size:14px; }
.important_text{color:#369; font-weight: bold;}
.log_info{color:#000; }
.normal_info{color:#666; }
.maintitle{font-size: 18px;}
.title{background-color:#369; border:1px solid #369; color:#fff}
</style>
	</head><body><div> <br/> <br/> <br/></div><table style='line-height:28px' cellpadding='0' cellspacing='0' width='800'>
			<tr>
				<td align='center' rowspan='5' class='maintitle' width='50%'>"${PROJECT_TITLE}"</td>
				<td align='center' class='normal_info' width='25%'>"${PROJECT_NAME}" svn</td>
				<td width='25%'><span class='important_text'>"${svn_code}"</span></td>
			</tr>
		</table>"

MAIL_CONTENT=${MAIL_CONTENT}"<table style='line-height:28px;margin-top:10px;' cellpadding='0' cellspacing='0'  width='800'>
			<tr>
				<td class='normal_info' width='25%'>渠道</td>
				<td class='important_text' width='75%'>"${CHANNEL_INFO}"</td>
			</tr>
			<tr>
				<td class='normal_info' width='25%'>VersionCode:</td>
				<td width='75%' class='important_text'>"${VERSION_CODE}"</td>
			</tr>
			<tr>
				<td class='normal_info' width='25%'>VersionName</td>
				<td width='75%' class='important_text'>"${VERSION_NAME}"</td>
			</tr>
			<tr>
				<td class='normal_info' width='25%'>打包日期</td>
				<td width='75%'>"${PACKAGE_DATE}"</td>
			</tr>
			<tr>
				<td class='normal_info' width='25%'>包大小</td>
				<td width='75%'>"${PACKAGE_SIZE}" M</td>
			</tr>
			<tr>
				<td class='normal_info' width='25%'>备注</td>
				<td width='75%'></td>
			</tr>
		</table>"

#添加一个工程的svn日志，参数1：工程标题名称，参数2：工程svn日志文件名
function addProjectLog()
{
	MAIL_CONTENT=${MAIL_CONTENT}"<table style='line-height:28px;margin-top:10px;'  cellpadding='0' cellspacing='0'  width='800'>
			<tr>
				<td align='center' colspan='3' class='title' width='100%'>"$1"</td>
			</tr>"

	#1 as log start
	VAL_FLAG_SHOULD_START_NEW_LOG=0
	VAL_FLAG_IN_WRITE_LOG=0
	VAL_FLAG_IS_EMPTY=0
	while read line
	do
		# replace " -" & " \-" to avoid html exception in thunderbird
		line=${line// -/-}
		line=${line// \\-/-}

		# log start with "--------------------"
		if [ "" != "${line}" ];then
		if [ "" != "${line}" -a "" = "${line//-/}" ];then
			if [ ${VAL_FLAG_IN_WRITE_LOG} -eq 1 ];then
				MAIL_CONTENT=${MAIL_CONTENT}"</td></tr>"
				VAL_FLAG_IN_WRITE_LOG=0
			fi
			#remenber new log start
			VAL_FLAG_SHOULD_START_NEW_LOG=1
		else
			if [ ${VAL_FLAG_SHOULD_START_NEW_LOG} -eq 1 ];then
				VAL_TMP=${line#*|}
				VAL_TMP2=${VAL_TMP#*|}
				MAIL_CONTENT=${MAIL_CONTENT}"<tr>
					<td class='normal_info' width='25%'>"${line%%|*}"</td>
					<td class='normal_info' width='25%'>"${VAL_TMP%%|*}"</td>
					<td class='normal_info' width='50%'>"${VAL_TMP2%%|*}"</td>
				</tr>"
			else
				if [ ${VAL_FLAG_IN_WRITE_LOG} -eq 1 ];then
					MAIL_CONTENT=${MAIL_CONTENT}"</br>"${line}
				else
					MAIL_CONTENT=${MAIL_CONTENT}"<tr><td colspan='3' width='100%'>"${line}
					VAL_FLAG_IN_WRITE_LOG=1
				fi
			fi
			VAL_FLAG_SHOULD_START_NEW_LOG=0
			VAL_FLAG_IS_EMPTY=1
		fi
		fi
	done < $2

	if [ ${VAL_FLAG_SHOULD_START_NEW_LOG} -eq 1 -a ${VAL_FLAG_IS_EMPTY} -eq 0 ];then
		MAIL_CONTENT=${MAIL_CONTENT}"<tr><td class='normal_info' align='center' colspan='3' width='100%'>无</td></tr>"
	fi
	MAIL_CONTENT=${MAIL_CONTENT}"</table>"
}

#SVN_LOG_FILE_1=$(cat ./build-config.txt | grep SVN_LOG_FILE_NAME | cut -d "=" -f 2)

addProjectLog "COMMIT LOG" ${SVN_LOG_FILE}

MAIL_CONTENT=${MAIL_CONTENT}"<table></table></body></html>"
#写入前先清除历史log
echo > jenkins-build-svnchangelog.html
#写格式化后个邮件到html中，供jenkins发送邮件时读取
echo ${MAIL_CONTENT} >> jenkins-build-svnchangelog.html


