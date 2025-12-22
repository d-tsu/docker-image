# vsftpd Docker Image

軽量なAlpineベースのvsftpd FTPサーバのDockerイメージです。匿名アクセス、認証付きアクセス、アクティブモード、パッシブモード、SSL/TLS接続など、様々な接続パターンをサポートしています。

## 特徴

- 軽量なAlpine Linuxベース
- vsftpdによる安定したFTPサーバ実装
- 環境変数による柔軟な設定
- 以下の接続パターンをサポート：
  - 匿名アクセス（anonymous）および認証付きアクセス（authenticated user）
  - アクティブモードおよびパッシブモード
  - 非TLS接続およびTLS接続（Explicit/Implicit SSL）
- コンテナログへの標準出力対応
- Docker Composeによる簡単なデプロイ

## 基本的な使い方

### Dockerイメージのビルド

```bash
docker build -t vsftpd-server .
```

### docker runでの起動

> **注意**: 一部の環境では、vsftpdがseccompサンドボックスの制限により正常に動作しない場合があります。その場合は `--security-opt seccomp=unconfined` オプションを追加してください。

#### 最小構成（デフォルト設定）

```bash
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  --name vsftpd \
  vsftpd-server
```

この設定では以下がデフォルトで有効になります：
- 匿名アクセス（ユーザー名: `anonymous`）
- 認証付きアクセス（ユーザー名: `ftpuser`、パスワード: `ftppass`）
- パッシブモード（ポート範囲: 21100-21110）

#### 認証付きアクセスのみ（カスタムユーザー）

```bash
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=NO \
  -e LOCAL_ENABLE=YES \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  --name vsftpd \
  vsftpd-server
```

#### SSL/TLS対応（Explicit SSL）

```bash
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e SSL_ENABLE=YES \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  --name vsftpd \
  vsftpd-server
```

#### パッシブモードの外部アドレス指定

Docker環境やNATの背後で動作する場合：

```bash
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e PASV_ADDRESS=192.168.1.100 \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  --name vsftpd \
  vsftpd-server
```

#### データの永続化（ボリュームマウント）

```bash
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e FTP_USER=myuser \
  -e FTP_PASS=mypassword \
  -v $(pwd)/data/ftp:/var/ftp:rw \
  -v $(pwd)/data/home:/home:rw \
  --name vsftpd \
  vsftpd-server
```

### ログの確認

```bash
docker logs -f vsftpd
```

### コンテナの停止・削除

```bash
# 停止
docker stop vsftpd

# 削除
docker rm vsftpd

# 停止して削除
docker rm -f vsftpd
```

## Docker Composeでの使い方（応用）

複数の環境変数を管理しやすくするために、Docker Composeを使用することもできます。

### 1. 環境変数の設定

`.env.example`をコピーして`.env`ファイルを作成し、必要に応じて設定を変更します：

```bash
cp .env.example .env
```

### 2. コンテナの起動

```bash
docker-compose up -d
```

### 3. ログの確認

```bash
docker-compose logs -f
```

### 4. コンテナの停止・削除

```bash
# 停止
docker-compose stop

# 停止して削除
docker-compose down

# ボリュームも含めて削除
docker-compose down -v
```

## 環境変数

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `FTP_USER` | `ftpuser` | FTP認証ユーザー名 |
| `FTP_PASS` | `ftppass` | FTP認証ユーザーのパスワード |
| `FTP_UID` | `1000` | FTPユーザーのUID |
| `FTP_GID` | `1000` | FTPユーザーのGID |
| `ANONYMOUS_ENABLE` | `YES` | 匿名アクセスの許可（YES/NO） |
| `ANON_UPLOAD_ENABLE` | `NO` | 匿名ユーザーのアップロード許可（YES/NO） |
| `ANON_MKDIR_WRITE_ENABLE` | `NO` | 匿名ユーザーのディレクトリ作成許可（YES/NO） |
| `LOCAL_ENABLE` | `YES` | ローカルユーザーログインの許可（YES/NO） |
| `WRITE_ENABLE` | `YES` | 書き込み許可（YES/NO） |
| `PASV_MIN_PORT` | `21100` | パッシブモードの最小ポート |
| `PASV_MAX_PORT` | `21110` | パッシブモードの最大ポート |
| `PASV_ADDRESS` | (空) | パッシブモード用の外部IPアドレス/ホスト名 |
| `SSL_ENABLE` | `NO` | SSL/TLSの有効化（YES/NO） |
| `IMPLICIT_SSL` | `NO` | Implicit SSL (FTPS)の使用（YES/NO） |

## 接続パターン別の設定例

### パターン1: 匿名アクセス（読み取りのみ、パッシブモード、非TLS）

```env
ANONYMOUS_ENABLE=YES
ANON_UPLOAD_ENABLE=NO
LOCAL_ENABLE=NO
SSL_ENABLE=NO
```

### パターン2: 認証付きアクセス（読み書き可能、パッシブモード、非TLS）

```env
ANONYMOUS_ENABLE=NO
LOCAL_ENABLE=YES
WRITE_ENABLE=YES
SSL_ENABLE=NO
FTP_USER=myuser
FTP_PASS=mypassword
```

### パターン3: 認証付きアクセス（Explicit SSL/TLS）

```env
ANONYMOUS_ENABLE=NO
LOCAL_ENABLE=YES
WRITE_ENABLE=YES
SSL_ENABLE=YES
IMPLICIT_SSL=NO
FTP_USER=myuser
FTP_PASS=mypassword
```

### パターン4: 混在モード（匿名＋認証、SSL/TLS対応）

```env
ANONYMOUS_ENABLE=YES
ANON_UPLOAD_ENABLE=NO
LOCAL_ENABLE=YES
WRITE_ENABLE=YES
SSL_ENABLE=YES
FTP_USER=myuser
FTP_PASS=mypassword
```

### パッシブモードの外部アドレス設定

Docker環境やNATの背後で動作する場合、パッシブモードで接続するには外部IPアドレスまたはホスト名を設定する必要があります：

```env
PASV_ADDRESS=192.168.1.100
# または
PASV_ADDRESS=ftp.example.com
```

## テスト手順

以下の手順で、様々な接続パターンをテストできます。テストには`lftp`クライアントを使用します。

### lftpのインストール

**macOS:**
```bash
brew install lftp
```

**Ubuntu/Debian:**
```bash
sudo apt-get install lftp
```

**RHEL/CentOS:**
```bash
sudo yum install lftp
```

### 自動テストスクリプト

プロジェクトには、4つの接続パターン（非TLS/TLS × 匿名/認証ユーザー）でCRUD操作を自動検証するスクリプトが含まれています。

```bash
sudo ./test_crud.sh
```

> **注意**: このスクリプトはDockerコンテナを起動・削除するため、root権限が必要です。

このスクリプトは以下をテストします：
- **Create**: ファイルアップロード、ディレクトリ作成
- **Read**: ディレクトリ一覧表示、ファイルダウンロード（内容検証含む）
- **Delete**: ファイル削除、ディレクトリ削除

各パターンで7つのテスト項目を実行し、合計28項目の検証を行います。全テストが正常に完了すると、以下のような結果が表示されます：

```
==========================================
テスト結果サマリー
==========================================
合格: 28
不合格: 0
合計: 28

すべてのテストに合格しました！
```

### 個別テストケース

個別のパターンを手動でテストする場合は、以下の手順を使用してください。

> **注意**: アクティブモードはコンテナ環境の制約により正常に動作しません。これはコンテナからクライアントへの接続が確立できないためです。実運用ではパッシブモードの使用を推奨します。

#### 1. 匿名アクセス（非TLS、パッシブモード）

```bash
# コンテナの起動
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=YES \
  -e LOCAL_ENABLE=NO \
  -e SSL_ENABLE=NO \
  --name vsftpd-test \
  vsftpd-server

# 少し待ってから接続テスト
sleep 3
lftp -e "set ftp:passive-mode true; ls; quit" ftp://anonymous:@localhost

# テスト後のクリーンアップ
docker rm -f vsftpd-test
```

#### 2. 認証付きアクセス（非TLS、パッシブモード）

```bash
# コンテナの起動
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
  vsftpd-server

# テスト（リスト表示）
sleep 3
lftp -u testuser,testpass -e "set ftp:passive-mode true; ls; quit" ftp://localhost

# テスト（ファイルアップロード）
echo "test content" > test.txt
lftp -u testuser,testpass -e "set ftp:passive-mode true; cd ftp/upload; put test.txt; ls; quit" ftp://localhost
rm test.txt

# クリーンアップ
docker rm -f vsftpd-test
```

#### 3. 認証付きアクセス（Explicit SSL/TLS、パッシブモード）

> **注意**: SSL/TLS環境では`--security-opt seccomp=unconfined`が必要です。

```bash
# コンテナの起動
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
  vsftpd-server

# テスト（CRUD操作）
sleep 3
echo "test data" > test.txt
lftp -u testuser,testpass -e "set ssl:verify-certificate no; set ftp:ssl-allow yes; set ftp:ssl-protect-data yes; set ftp:passive-mode true; cd ftp/upload; put test.txt; ls -la; get test.txt -o downloaded.txt; rm test.txt; quit" ftp://localhost
cat downloaded.txt
rm test.txt downloaded.txt

# クリーンアップ
docker rm -f vsftpd-test
```

#### 4. 混在モード（匿名＋認証、SSL対応）

```bash
# コンテナの起動
docker run -d \
  -p 21:21 \
  -p 21100-21110:21100-21110 \
  -e ANONYMOUS_ENABLE=YES \
  -e ANON_UPLOAD_ENABLE=NO \
  -e LOCAL_ENABLE=YES \
  -e WRITE_ENABLE=YES \
  -e SSL_ENABLE=YES \
  -e FTP_USER=testuser \
  -e FTP_PASS=testpass \
  --name vsftpd-test \
  vsftpd-server

# 匿名アクセステスト（非SSL）
sleep 3
lftp -e "ls; quit" ftp://anonymous:@localhost

# 認証アクセステスト（SSL）
lftp -u testuser,testpass -e "set ssl:verify-certificate no; set ftp:ssl-allow yes; ls; quit" ftp://localhost

# クリーンアップ
docker rm -f vsftpd-test
```

### 対話的なテスト

より詳細なテストを行いたい場合は、対話モードで接続します：

```bash
# 匿名アクセス
lftp ftp://anonymous:@localhost

# 認証付きアクセス
lftp -u testuser,testpass ftp://localhost

# SSL/TLS付き認証アクセス
lftp -u testuser,testpass -e "set ssl:verify-certificate no; set ftp:ssl-allow yes" ftp://localhost
```

対話モードでの主なコマンド：
- `ls` - ディレクトリ一覧表示
- `cd <dir>` - ディレクトリ移動
- `get <file>` - ファイルダウンロード
- `put <file>` - ファイルアップロード
- `mkdir <dir>` - ディレクトリ作成
- `rm <file>` - ファイル削除
- `quit` - 終了

## ディレクトリ構造

```
/var/ftp/              # 匿名ユーザー用のルートディレクトリ
  └── pub/             # 匿名ユーザーがアクセスできるディレクトリ
      └── upload/      # アップロード用ディレクトリ（設定による）

/home/<FTP_USER>/      # 認証ユーザーのホームディレクトリ
  └── ftp/             # chrootされたFTPディレクトリ
      └── upload/      # アップロード用ディレクトリ
```

## トラブルシューティング

### パッシブモードで接続できない

Docker環境やNATの背後で動作している場合、`PASV_ADDRESS`環境変数に外部IPアドレスまたはホスト名を設定してください。

```env
PASV_ADDRESS=<your-server-ip-or-hostname>
```

### ファイアウォールの設定

パッシブモードを使用する場合、以下のポートを開放する必要があります：
- ポート21（FTP制御接続）
- ポート21100-21110（パッシブモードデータ接続、デフォルト範囲）

### SSL証明書エラー

自己署名証明書を使用しているため、クライアント側で証明書検証をスキップする必要があります。

**lftpの場合:**
```bash
set ssl:verify-certificate no
```

**FileZillaの場合:**
証明書の警告が表示されたら「OK」をクリックして続行します。

### SSL/TLS使用時の注意事項

SSL/TLS接続を使用する場合は、以下の点に注意してください：

**seccompの無効化が必要**:
```bash
--security-opt seccomp=unconfined
```

このオプションは、OpenSSLの暗号化処理に必要なシステムコールをコンテナ内で実行するために必要です。

**自己署名証明書**:
デフォルトでは自己署名証明書を使用するため、クライアント側で証明書検証をスキップする必要があります（lftpの場合: `set ssl:verify-certificate no`）。

**本番環境での推奨**:
本番環境では、正式な認証局（CA）から発行された証明書を使用し、適切な証明書検証を行うことを推奨します。


## ライセンス

このプロジェクトのライセンスについては、LICENSEファイルを参照してください。

## 参考情報

- [vsftpd公式サイト](https://security.appspot.com/vsftpd.html)
- [vsftpd設定リファレンス](https://linux.die.net/man/5/vsftpd.conf)
- [Alpine Linux](https://alpinelinux.org/)