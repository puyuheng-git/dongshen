<?php
/**
 * 统计代码量脚本
 * @describtion 使用方法：进入代码仓库下运行 php stat_code.php author 'start_time' 'end_time' 例如统计用户wenxianghao2023年9月service-app的代码量：cd ~/service/service-app && /usr/local/php/bin/php ~/op/tool/stat_code.php wenxianghao '2023-09-01 00:00:00' '2023-10-01 00:00:00'
 * @filesource stat_code.php
 * @author: wenxianghao
 * @date: 2023/10/9 14:10
 * @copyright Copyright(c)2021-2022,dscpa.cn. All Rights Reserved
 */
if (strtolower(php_sapi_name()) !== 'cli')
{
    die('请求方式错误');
}
$author = escapeshellarg($argv[1]);
$startTime = escapeshellarg($argv[2]);
$endTime = escapeshellarg($argv[3]);
//计算总行数
exec("git log --since='{$startTime}' --before='{$endTime}' --author='{$author}' --pretty=tformat: --numstat | awk '{ add += $1;subs +=$2;loc += $1-$2} END {printf \"%s\",add}'", $totalLineRes);
$totalLine = $totalLineRes[0];
//获取所有提交的id
exec("git log --oneline --author={$author} --since='{$startTime}' --before='{$endTime}'", $logRes);
$commitIdArr = array();
foreach ($logRes as $line)
{
    $lineSplit = explode(' ', $line);
    $commitIdArr[] = $lineSplit[0];
}
/**
 * 根据提交的id获取每个文件的变更行数
 */
$commitFileStat = array();
$totalLineNum = $totalValidLineNum = $totalNotValidLineNum = 0;
foreach ($commitIdArr as $key => $commitId)
{
    $commitFileStatItem = array();
//    $command = "git show $commitId | grep '^+'";
    $command = "git show --pretty=format: --no-color --unified=0 {$commitId}";
    $commitFileChange = array();
    exec($command, $commitFileChange);
    //判断是否是文件
    $fileTotalLineNum = $validLineNum = $notValidLineNum = 0;
    $fileName = '';
    foreach ($commitFileChange as $line)
    {
        //判断是否是文件
//        if (strpos($line, '+++') !== false)
        if (strpos($line, '+++ b/') === 0)
        {
            $fileName = str_replace('+++ b/', '', $line);
            $fileTotalLineNum = $validLineNum = $notValidLineNum = 0;
        }
        else
        {
            if (strpos($line, '+') !== 0 || strpos($line, '+++') === 0)
            {
                continue;
            }
            $fileTotalLineNum++;
            //判断是否是Export文件
//            if (strpos($fileName, 'Export.php'))
            if ($fileName !== '' && preg_match('/(^|\/)Export\.php$/', $fileName))
            {
                $notValidLineNum++;
            }
            else
            {
                //判断是否是Exception
               // if (strpos($line, 'Exception') && strpos($line, '*'))
                if (strpos($line, 'Exception') !== false && strpos($line, '*') !== false)
                {
                    $notValidLineNum++;
                }
                else
                {
                    $validLineNum++;
                }
            }
            $commitFileStatItem[$fileName] = array(
                'total_line_num'     => $fileTotalLineNum,
                'valid_line_num'     => $validLineNum,
                'not_valid_line_num' => $notValidLineNum,
            );
        }
    }
    $totalLineNum += array_sum(array_column($commitFileStatItem, 'total_line_num'));
    $totalValidLineNum += array_sum(array_column($commitFileStatItem, 'valid_line_num'));
    $totalNotValidLineNum += array_sum(array_column($commitFileStatItem, 'not_valid_line_num'));
    $commitFileStat[$commitId] = $commitFileStatItem;
}
//有效代码行数（去除Export和Exception）  总行数  无效代码行数
echo '代码行数: ' . $totalValidLineNum ;

