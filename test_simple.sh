#!/bin/bash

# 簡易FTPテストスクリプト - デバッグ用

echo "=== 匿名アクセス 非TLS テスト ==="

# クリーンアップ
docker rm -f vsftpd-test 2>/dev/null || true
rm -f test_anon.txt dl_anon.txt 2>/dev/null || true

# コンテナ起動
echo "コンテナ起動中..."
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=YES \
  -e ANON_UPLOAD_ENABLE=YES \
  -e ANON_MKDIR_WRITE_ENABLE=YES \
  -e LOCAL_ENABLE=NO \
  -e SSL_ENABLE=NO \
  --name vsftpd-test \
  vsftpd-server > /dev/null

sleep 3

# Create - アップロード
echo "1. ファイルアップロード..."
echo "test data" > test_anon.txt
if lftp -u anonymous, -e "set ftp:passive-mode true; put -O upload test_anon.txt; quit" ftp://localhost 2>&1 | grep -q "transferred"; then
    echo "   ✓ アップロード成功"
else
    echo "   ✗ アップロード失敗"
fi

# Create - ディレクトリ作成
echo "2. ディレクトリ作成..."
if lftp -u anonymous, -e "set ftp:passive-mode true; mkdir upload/testdir; quit" ftp://localhost 2>&1 | grep -q "成功"; then
    echo "   ✓ ディレクトリ作成成功"
else
    echo "   ✗ ディレクトリ作成失敗"
fi

# Read - リスト表示
echo "3. ディレクトリ一覧..."
if lftp -u anonymous, -e "set ftp:passive-mode true; ls upload/; quit" ftp://localhost 2>&1 | grep -q "test_anon.txt"; then
    echo "   ✓ リスト表示成功"
else
    echo "   ✗ リスト表示失敗"
fi

# Read - ダウンロード
echo "4. ファイルダウンロード..."
if lftp -u anonymous, -e "set ftp:passive-mode true; get upload/test_anon.txt -o dl_anon.txt; quit" ftp://localhost 2>&1 | grep -q "transferred"; then
    if [ -f dl_anon.txt ] && [ "$(cat dl_anon.txt)" = "test data" ]; then
        echo "   ✓ ダウンロード成功（内容確認OK）"
    else
        echo "   ✗ ダウンロード失敗（内容不一致）"
    fi
else
    echo "   ✗ ダウンロード失敗"
fi

# Delete - ファイル削除
echo "5. ファイル削除..."
if lftp -u anonymous, -e "set ftp:passive-mode true; rm upload/test_anon.txt; quit" ftp://localhost 2>&1 | grep -q "成功"; then
    echo "   ✓ ファイル削除成功"
else
    echo "   ✗ ファイル削除失敗"
fi

# Delete - ディレクトリ削除
echo "6. ディレクトリ削除..."
if lftp -u anonymous, -e "set ftp:passive-mode true; rmdir upload/testdir; quit" ftp://localhost 2>&1 | grep -q "成功"; then
    echo "   ✓ ディレクトリ削除成功"
else
    echo "   ✗ ディレクトリ削除失敗"
fi

# クリーンアップ
echo ""
echo "クリーンアップ中..."
docker rm -f vsftpd-test > /dev/null 2>&1
rm -f test_anon.txt dl_anon.txt 2>/dev/null

echo "テスト完了"
