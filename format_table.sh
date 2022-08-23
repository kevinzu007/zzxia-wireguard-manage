#!/bin/bash
# 修改人：zhf_sy
# Test On: CentOS 7
#
# 原作者信息如下：
# https://blog.csdn.net/virnet/article/details/76273512
#Filename:      format_table.sh
#Revision:      0.2
#Date:          2017/8/23
#Author:        sunlinyao
#Description:   shell下格式化输出为表格样式
#               使用时首先需要调用set_title对表格初始化
#               追加表格数据可使用append_cell和append_line，append_cell不会自动换行，换行必须要使用append_line
#               append_line参数是可选的，并且会自动对之前的append_cell换行
#               使用output_table可输出表格
#               暂不支持修改/插入/删除数据
#               可使用. format_table.sh 或者source format_table.sh来引入改脚本的函数
#               "(*)"会自动着色为红色字体
#注：以Centos6.5标准写的，在其他系统上可能结果有差异，欢迎大家测试使用以及反馈八阿哥
# [root@virnet ~]# bash format_table.sh
# +----+------+---------------+
# |ID  |Name  |Creation time  |
# +----+------+---------------+
# |1   |TF    |2017-01-01     |
# |2   |      |2017-01-02(*)  |
# |3   |SF    |               |
# |3   |SF    |(*)            |
# |4   |TS    |               |
# |5   |      |               |
# +----+------+---------------+



# sh
SH_NAME=${0##*/}
SH_PATH=$( cd "$( dirname "$0" )" && pwd )
#cd ${SH_PATH}

# env
sep="§"


# 用法：
F_HELP()
{
    echo "
    用途：将数据输出为表格
    依赖：
    注意：
    用法:
        $0 [-h|--help]
        $0 <-d|--delimeter {分隔符}>  <-t|--title {字段名1, 字段名2, ...}>  <-r|--row {值1, 值2, ...}>  <-f|--file {文件x}    #--- 默认分隔符为【,】
    参数说明：
        \$0   : 代表脚本本身
        []   : 代表是必选项
        <>   : 代表是可选项
        |    : 代表左右选其一
        {}   : 代表参数值，请替换为具体参数值
        %    : 代表通配符，非精确值，可以被包含
        #
        -d|--delimeter  : 表格分隔符，默认分隔符为【,】
        -t|--title      ：标题，例如： 'aa, bb,cc'
        -r|--row        : 行，例如：'aaaa, bbbbb,cccc'
        -f|--file       : 表格文件名
    示例：
        #
        $0          -f 文件1          #--- 默认分隔符，标题与内容皆取自【文件1】
        $0  -d '|'  -f 文件1          #--- 分隔符为【|】，标题与内容皆取自【文件1】
        #
        $0  -d '|'  -t 'A|B|C'  -r 'aa|bb|cc'  -r 'vv| |xx'    #--- 定义标题，内容取自【'aa|bb|cc' ； 'vv| |xx'】
        $0  -d '|'  -t 'A|B|C'  -f 文件1                       #--- 定义标题，内容取自【文件1】
"
}



# 设置title
function set_title(){
    #表格标头，以空格分割，包含空格的字符串用引号，如
    #set_title Column_0 "Column 1" "" Column3
    [ -n "$title" ] && echo "Warring:表头已经定义过,重写表头和内容"
    column_count=0
    title=""
    local i
    for i in "$@"
    do
        title+="|${i}${sep}"
        let column_count++
    done
    title+="|\n"
    seg=`segmentation`
    title="${seg}${title}${seg}"
    content=""
}


# 追加表格内容(content)
function check_line(){
    if [ -n "$line" ]
    then
        c_c=$(echo $line|tr -cd "${sep}"|wc -c)
        difference=$((${column_count}-${c_c}))
        if [ $difference -gt 0 ]
        then
            line+=$(seq -s " " $difference|sed -r s/[0-9]\+/\|${sep}/g|sed -r  s/${sep}\ /${sep}/g)
        fi
        content+="${line}|\n"
    fi
}


# 不换行追加
function append_cell(){
    #对表格追加单元格
    #append_cell col0 "col 1" ""
    #append_cell col3
    local i
    for i in "$@"
    do
        line+="|$i${sep}"
    done
}


# 换行追加
function append_line(){
    check_line
    line=""
    local i
    for i in "$@"
    do
        line+="|$i${sep}"
    done
    check_line
    line=""
}


# 表格横线
function segmentation(){
    local seg=""
    local i
    for i in $(seq $column_count)
    do
        seg+="+${sep}"
    done
    #seg+="${sep}+\n"
    seg+="+\n"
    echo $seg
}


# 整合输出
function output_table(){
    if [ ! -n "${title}" ]
    then
        echo "未设置表头，退出" && return 1
    fi
    append_line
    table="${title}${content}$(segmentation)"
    # ◘ : 空格
    table=`echo "${table}" | sed 's/◘/ /g'`
    # ✖ : 空
    table=`echo "${table}" | sed 's/✖//g'`
    #echo -e "${table}"
    #echo -e $table|column -s "${sep}" -t|awk '{if($0 ~ /^+/){gsub(" ","-",$0);print $0}else{gsub("\\(\\*\\)","\033[31m(*)\033[0m",$0);print $0}}'
    #echo -e $table|column -s "${sep}" -t|awk '{if($0 ~ /^+/){gsub(" ","-",$0);print $0}else{gsub("\\*","\033[31m*\033[0m",$0);gsub("错误","\033[31m错误\033[0m",$0);gsub("失败","\033[31m失败\033[0m",$0);gsub("成功","\033[32;1m成功\033[0m",$0);print $0}}'
    echo -e $table|column -s "${sep}" -t|awk '{if($0 ~ /^\+/){gsub(" ","-",$0);print $0}else{gsub("\\*","\033[31m*\033[0m",$0);gsub("错误","\033[31m错误\033[0m",$0);gsub("失败","\033[31m失败\033[0m",$0);gsub("成功","\033[32;1m成功\033[0m",$0);print $0}}'
    #echo -e $table|column -s "${sep}" -t|awk '{if($0 ~ /^+/){gsub(" ","-",$0);print $0}else{gsub("\\*","\033[31m*\033[0m",$0);gsub("错误","\033[31m错误\033[0m",$0);gsub("失败","\033[31m失败\033[0m",$0);gsub("成功","\033[32;1m成功\033[0m",$0);gsub("已发布","\033[32;1m已发布\033[0m",$0);print $0}}'
}



# 示例：
#if [ "$SHLVL" -eq "2" ]
#then
#    set_title ID Name "Creation time"
#    append_line 1 "TF" "2017-01-01"
#    append_line 1 "TF" "2017-01-01"
#    append_line 1 "TF" "2017-01-01"
#    append_cell 2 "" "2017-01-02(*)"
#    append_line
#    append_cell 3 "SF"
#    append_line
#    append_cell 3 "SF" "(*)"
#    append_cell 3 "SF" "(*)"
#    append_line 4 "TS"
#    append_cell 5
#    output_table
#fi

# 示例2：
#set_title 项目 状态
#append_line  gclife-renewal-front*  "Build 成功(*)"
#append_line  gclife-renewal-front  "Build(*) 成功"
#output_table




# 参数检查
TEMP=`getopt  -o hd:t:r:f:  -l help,delimeter:,title:,row:,file: -- "$@"`
if [ $? != 0 ]; then
    echo -e "\n峰哥说：参数不合法，请查看帮助【$0 --help】\n"
    exit 1
fi
#
eval set -- "${TEMP}"


# 获取次要命令参数
SH_ARGS_NUM=$#
SH_ARGS[0]="占位"
for ((i=1;i<=SH_ARGS_NUM;i++)); do
    eval K=\${${i}}
    SH_ARGS[${i}]=${K}
    #echo SH_ARGS数组${i}列的值是: ${SH_ARGS[${i}]}
done
#
SH_ARGS_ARR_NUM=${#SH_ARGS[@]}
for ((i=1;i<SH_ARGS_ARR_NUM;i++))
do
    case ${SH_ARGS[$i]} in
        -h|--help)
            F_HELP
            exit
            ;;
        -d|--delimeter)
            j=$((i+1))
            J=${SH_ARGS[$j]}
            T_DELIMETER=$J
            ;;
        -t|--title)
            j=$((i+1))
            J=${SH_ARGS[$j]}
            T_TITLE=$J
            ;;
        --)
            break
            ;;
        *)
            # 跳过
            ;;
    esac
done

# 默认值
T_DELIMETER=${T_DELIMETER:-','}



# 读取字段值
F_LINE()
{
    LINE="$1"
    FILED_OK=''
    FILED_SUM=`echo "${LINE}" | grep -o "${T_DELIMETER}" | wc -l`
    for ((i=0;i<=FILED_SUM;i++))
    do
        let k=$i+1
        FILED=`echo "${LINE}" | cut -d "${T_DELIMETER}" -f $k`
        FILED=`echo ${FILED}`
        # 空格
        FILED=`echo "${FILED}" | sed 's/ /◘/g'`
        # 空
        [ "x${FILED}" = "x" ] && FILED='✖'
        # 组合
        FILED_OK="${FILED_OK}  ${FILED}"
    done
    echo  "${FILED_OK}"
}


# title
if [ -n "${T_TITLE}" ]; then
    set_title '序号'  `F_LINE "${T_TITLE}"`
fi



#
T_ROW=''
i=1
while true
do
    case $1 in
        -h|--help)
            F_HELP
            exit
            ;;
        -d|--delimeter|-t|--title)
            shift 2
            ;;
        -r|--row)
            if [ -z "${T_TITLE}" ]; then
                echo -e "\n峰哥说：你还没设置标题呢！\n"
                exit 1
            fi
            T_ROW="$2"
            append_line  "$i"  `F_LINE "${T_ROW}"`
            let i++
            shift 2
            ;;
        -f|--file)
            T_FILE=$2
            while read LINE
            do
                if [ -n "${T_TITLE}" ]; then
                    append_line  "$i"  `F_LINE "${LINE}"`
                    let i++
                else
                    set_title  '序号'  `F_LINE "${LINE}"`
                    T_TITLE="现在有了"
                fi
            done < ${T_FILE}
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo -e "\n峰哥说：未知参数，请查看帮助【$0 --help】\n"
            exit 1
            ;;
    esac
done


# 输出
output_table





