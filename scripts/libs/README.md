用于存放脚本内置工具的脚本

引用方式必须为：

```shell
. "$CRASHDIR"/libs/xxx.sh
```

返回码必须是return x而不能是exit x

此处脚本内容不应包含文字输出和log输出

`webget` 和 `web_get_lite` 在子 shell 中执行，临时代理和内部变量不会修改调用者环境。下载文件、标准输出和退出码仍按原有接口传递。

在仓库根目录运行代理环境隔离回归测试：

```sh
sh tests/test_webget_proxy_scope.sh
```