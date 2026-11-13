用于存放脚本内置工具的脚本

引用方式必须为：

```shell
. "$CRASHDIR"/libs/xxx.sh
```

返回码必须是return x而不能是exit x

此处脚本内容不应包含文字输出和log输出

`webget` 和 `web_get_lite` 在子 shell 中执行，临时代理和内部变量不会修改调用者环境。下载文件、标准输出和退出码仍按原有接口传递。

`webget` 成功返回 0，失败统一返回 1，不透传 wget 的 4、8 等退出码。使用 curl 下载时，只有 curl 退出码为 0 且 HTTP 状态码为 200 才算成功。失败时只删除本次调用新建的普通文件，调用前已存在的文件、符号链接和设备文件（如 `/dev/null`）不会被删除。GNU Wget 会在下载开始前清空已存在的目标文件，需要保留旧文件时应先下载到临时路径。

在仓库根目录运行回归测试：

```sh
sh tests/test_webget_proxy_scope.sh
sh tests/test_webget_curl_exit.sh
sh tests/test_webget_wget_exit.sh
```