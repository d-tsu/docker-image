#!/bin/bash

# FTPサーバCRUDテストスクリプト
# 4パターン（非TLS/TLS × anonymous/認証ユーザー）のCRUD操作を検証

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "FTP Server CRUD Test Script"
echo "=========================================="
echo ""

# クリーンアップ関数
cleanup() {
    echo -e "${YELLOW}クリーンアップ中...${NC}"
    docker rm -f vsftpd-test 2>/dev/null || true
    rm -f test_*.txt downloaded_*.txt 2>/dev/null || true
}

# テスト結果カウンター
PASSED=0
FAILED=0

# テスト実行関数
run_test() {
    local test_name=$1
    local command=$2
    
    echo -n "  ${test_name}... "
    if timeout 30 bash -c "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

# CRUD操作テスト関数
test_crud() {
    local test_label=$1
    local lftp_user=$2
    local upload_dir=$3
    local test_file=$4
    local downloaded_file=$5
    local ssl_opts=$6
    
    echo -e "${BLUE}=== ${test_label} ===${NC}"
    
    # SSL設定とパッシブモード設定を統合
    local base_settings="set net:timeout 30; set ftp:passive-mode true"
    if [ -n "$ssl_opts" ]; then
        base_settings="set net:timeout 30; set ssl:verify-certificate no; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:passive-mode true"
    fi
    
    # テストファイル作成
    echo "test data for ${test_label}" > "${test_file}"
    
    # すべてのCRUD操作を一つのlftpセッション内で実行
    echo -n "  すべてのCRUD操作を実行中... "
    if timeout 60 lftp ${lftp_user} -e "${base_settings}; \
        put -O ${upload_dir} ${test_file} && echo 'PUT_OK' || echo 'PUT_FAIL'; \
        mkdir ${upload_dir}/testdir && echo 'MKDIR_OK' || echo 'MKDIR_FAIL'; \
        ls ${upload_dir}/ && echo 'LS_OK' || echo 'LS_FAIL'; \
        get ${upload_dir}/${test_file} -o ${downloaded_file} && echo 'GET_OK' || echo 'GET_FAIL'; \
        rm ${upload_dir}/${test_file} && echo 'RM_OK' || echo 'RM_FAIL'; \
        rmdir ${upload_dir}/testdir && echo 'RMDIR_OK' || echo 'RMDIR_FAIL'; \
        quit" ftp://localhost > /tmp/crud_output_$$.txt 2>&1; then
        
        # 各操作の結果を個別にチェック
        if grep -q "PUT_OK" /tmp/crud_output_$$.txt; then
            echo -e "${GREEN}✓${NC}"
            echo -e "  Create (ファイルアップロード)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗${NC}"
            echo -e "  Create (ファイルアップロード)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        if grep -q "MKDIR_OK" /tmp/crud_output_$$.txt; then
            echo -e "  Create (ディレクトリ作成)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "  Create (ディレクトリ作成)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        if grep -q "LS_OK" /tmp/crud_output_$$.txt; then
            echo -e "  Read (ディレクトリ一覧)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "  Read (ディレクトリ一覧)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        if grep -q "GET_OK" /tmp/crud_output_$$.txt; then
            echo -e "  Read (ファイルダウンロード)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "  Read (ファイルダウンロード)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        # 内容検証
        if [ -f "${downloaded_file}" ]; then
            local expected="test data for ${test_label}"
            local actual=$(cat "${downloaded_file}")
            if [ "$expected" = "$actual" ]; then
                echo -e "  内容検証... ${GREEN}✓ PASS${NC}"
                ((PASSED++))
            else
                echo -e "  内容検証... ${RED}✗ FAIL${NC} (expected: '$expected', got: '$actual')"
                ((FAILED++))
            fi
        else
            echo -e "  内容検証... ${RED}✗ FAIL${NC} (ファイルが存在しません)"
            ((FAILED++))
        fi
        
        if grep -q "RM_OK" /tmp/crud_output_$$.txt; then
            echo -e "  Delete (ファイル削除)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "  Delete (ファイル削除)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        if grep -q "RMDIR_OK" /tmp/crud_output_$$.txt; then
            echo -e "  Delete (ディレクトリ削除)... ${GREEN}✓ PASS${NC}"
            ((PASSED++))
        else
            echo -e "  Delete (ディレクトリ削除)... ${RED}✗ FAIL${NC}"
            ((FAILED++))
        fi
        
        rm -f /tmp/crud_output_$$.txt
    else
        echo -e "${RED}✗ タイムアウトまたは接続失敗${NC}"
        echo -e "  Create (ファイルアップロード)... ${RED}✗ FAIL${NC}"
        echo -e "  Create (ディレクトリ作成)... ${RED}✗ FAIL${NC}"
        echo -e "  Read (ディレクトリ一覧)... ${RED}✗ FAIL${NC}"
        echo -e "  Read (ファイルダウンロード)... ${RED}✗ FAIL${NC}"
        echo -e "  内容検証... ${RED}✗ FAIL${NC}"
        echo -e "  Delete (ファイル削除)... ${RED}✗ FAIL${NC}"
        echo -e "  Delete (ディレクトリ削除)... ${RED}✗ FAIL${NC}"
        FAILED=$((FAILED + 7))
        rm -f /tmp/crud_output_$$.txt
    fi
    
    # ファイルクリーンアップ
    rm -f "${test_file}" "${downloaded_file}"
    
    echo ""
}

# テスト1: 匿名アクセス（非TLS）
echo -e "${YELLOW}[1/4] 匿名アクセス（非TLS、パッシブモード）${NC}"
cleanup
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=YES \
  -e ANON_UPLOAD_ENABLE=YES \
  -e ANON_MKDIR_WRITE_ENABLE=YES \
  -e LOCAL_ENABLE=NO \
  -e SSL_ENABLE=NO \
  --name vsftpd-test \
  vsftpd-server > /dev/null 2>&1

echo "コンテナ起動待機中..."
sleep 3

test_crud "匿名/非TLS" "-u anonymous," "upload" "test_anon_notls.txt" "downloaded_anon_notls.txt" ""

cleanup

# テスト2: 認証付きアクセス（非TLS）
echo -e "${YELLOW}[2/4] 認証付きアクセス（非TLS、パッシブモード）${NC}"
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=NO \
  -e LOCAL_ENABLE=YES \
  -e WRITE_ENABLE=YES \
  -e SSL_ENABLE=NO \
  -e FTP_USER=testuser \
  -e FTP_PASS=testpass \
  --name vsftpd-test \
  vsftpd-server > /dev/null 2>&1

echo "コンテナ起動待機中..."
sleep 3

test_crud "認証/非TLS" "-u testuser,testpass" "ftp/upload" "test_auth_notls.txt" "downloaded_auth_notls.txt" ""

cleanup

# テスト3: 匿名アクセス（SSL/TLS）
echo -e "${YELLOW}[3/4] 匿名アクセス（SSL/TLS、パッシブモード）${NC}"
docker run -d \
  --security-opt seccomp=unconfined \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=YES \
  -e ANON_UPLOAD_ENABLE=YES \
  -e ANON_MKDIR_WRITE_ENABLE=YES \
  -e LOCAL_ENABLE=NO \
  -e SSL_ENABLE=YES \
  -e IMPLICIT_SSL=NO \
  --name vsftpd-test \
  vsftpd-server > /dev/null 2>&1

echo "コンテナ起動待機中..."
sleep 3

test_crud "匿名/SSL" "-u anonymous," "upload" "test_anon_ssl.txt" "downloaded_anon_ssl.txt" "-e 'set ssl:verify-certificate no; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes'"

cleanup

# テスト4: 認証付きアクセス（SSL/TLS）
echo -e "${YELLOW}[4/4] 認証付きアクセス（SSL/TLS、パッシブモード）${NC}"
docker run -d \
  --security-opt seccomp=unconfined \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=NO \
  -e LOCAL_ENABLE=YES \
  -e WRITE_ENABLE=YES \
  -e SSL_ENABLE=YES \
  -e IMPLICIT_SSL=NO \
  -e FTP_USER=testuser \
  -e FTP_PASS=testpass \
  --name vsftpd-test \
  vsftpd-server > /dev/null 2>&1

echo "コンテナ起動待機中..."
sleep 3

test_crud "認証/SSL" "-u testuser,testpass" "ftp/upload" "test_auth_ssl.txt" "downloaded_auth_ssl.txt" "-e 'set ssl:verify-certificate no; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes'"

cleanup

# 結果サマリー
echo "=========================================="
echo -e "${BLUE}テスト結果サマリー${NC}"
echo "=========================================="
echo -e "合格: ${GREEN}${PASSED}${NC}"
echo -e "不合格: ${RED}${FAILED}${NC}"
echo -e "合計: $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}すべてのテストに合格しました！${NC}"
    exit 0
else
    echo -e "${RED}一部のテストが失敗しました。${NC}"
    exit 1
fi
