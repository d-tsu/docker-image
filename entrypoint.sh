#!/bin/bash
set -e

# デフォルト値の設定
FTP_USER="${FTP_USER:-ftpuser}"
FTP_PASS="${FTP_PASS:-ftppass}"
FTP_UID="${FTP_UID:-1000}"
FTP_GID="${FTP_GID:-1000}"
PASV_MIN_PORT="${PASV_MIN_PORT:-21100}"
PASV_MAX_PORT="${PASV_MAX_PORT:-21110}"
PASV_ADDRESS="${PASV_ADDRESS:-}"
ANONYMOUS_ENABLE="${ANONYMOUS_ENABLE:-YES}"
LOCAL_ENABLE="${LOCAL_ENABLE:-YES}"
WRITE_ENABLE="${WRITE_ENABLE:-YES}"
ANON_UPLOAD_ENABLE="${ANON_UPLOAD_ENABLE:-NO}"
ANON_MKDIR_WRITE_ENABLE="${ANON_MKDIR_WRITE_ENABLE:-NO}"
SSL_ENABLE="${SSL_ENABLE:-NO}"
IMPLICIT_SSL="${IMPLICIT_SSL:-NO}"

echo "=========================================="
echo "FTP Server Configuration"
echo "=========================================="
echo "Anonymous access: ${ANONYMOUS_ENABLE}"
echo "Local user access: ${LOCAL_ENABLE}"
echo "Write enable: ${WRITE_ENABLE}"
echo "SSL enable: ${SSL_ENABLE}"
echo "Passive mode ports: ${PASV_MIN_PORT}-${PASV_MAX_PORT}"
if [ -n "${PASV_ADDRESS}" ]; then
    echo "Passive mode address: ${PASV_ADDRESS}"
fi
echo "=========================================="

# FTPユーザーの作成（LOCAL_ENABLEがYESの場合）
if [ "${LOCAL_ENABLE}" = "YES" ]; then
    # グループの作成
    if ! getent group "${FTP_GID}" > /dev/null 2>&1; then
        addgroup -g "${FTP_GID}" ftpgroup
    fi
    
    # ユーザーの作成
    if ! id -u "${FTP_USER}" > /dev/null 2>&1; then
        adduser -D -u "${FTP_UID}" -G ftpgroup -h /home/"${FTP_USER}" -s /bin/false "${FTP_USER}"
        echo "${FTP_USER}:${FTP_PASS}" | chpasswd
        echo "Created FTP user: ${FTP_USER}"
        
        # ホームディレクトリの作成と権限設定
        mkdir -p /home/"${FTP_USER}"/ftp/upload
        chown -R "${FTP_USER}":"ftpgroup" /home/"${FTP_USER}"/ftp
        chmod 755 /home/"${FTP_USER}"/ftp
        chmod 755 /home/"${FTP_USER}"/ftp/upload
        
        # chrootの場合、ホームディレクトリは書き込み不可にする必要がある
        chown root:root /home/"${FTP_USER}"
        chmod 755 /home/"${FTP_USER}"
    fi
    
    # ユーザーリストの作成
    echo "${FTP_USER}" > /etc/vsftpd/user_list
fi

# 匿名アクセス用のディレクトリ設定
if [ "${ANONYMOUS_ENABLE}" = "YES" ]; then
    mkdir -p /var/ftp/pub/upload
    # /var/ftpはroot所有、読み取り専用（セキュリティ要件）
    chown root:ftp /var/ftp
    chmod 555 /var/ftp
    # /var/ftp/pubはftp所有、読み取り可能
    chown ftp:ftp /var/ftp/pub
    chmod 555 /var/ftp/pub
    # /var/ftp/pub/uploadは書き込み可能（ANON_UPLOAD_ENABLEがYESの場合）
    chown ftp:ftp /var/ftp/pub/upload
    chmod 755 /var/ftp/pub/upload
fi

# SSL証明書の生成（SSL_ENABLEがYESの場合）
if [ "${SSL_ENABLE}" = "YES" ]; then
    if [ ! -f /etc/ssl/private/vsftpd.pem ]; then
        echo "Generating self-signed SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/vsftpd.pem \
            -out /etc/ssl/private/vsftpd.pem \
            -subj "/C=JP/ST=Tokyo/L=Tokyo/O=FTP Server/CN=localhost"
        chmod 600 /etc/ssl/private/vsftpd.pem
        echo "SSL certificate generated."
    fi
fi

# vsftpd設定ファイルの生成
cat > /etc/vsftpd/vsftpd.conf <<EOF
# 基本設定
listen=YES
listen_ipv6=NO
background=NO
seccomp_sandbox=NO

# 匿名アクセス設定
anonymous_enable=${ANONYMOUS_ENABLE}
anon_upload_enable=${ANON_UPLOAD_ENABLE}
anon_mkdir_write_enable=${ANON_MKDIR_WRITE_ENABLE}
anon_other_write_enable=${ANON_MKDIR_WRITE_ENABLE}
no_anon_password=YES
anon_root=/var/ftp/pub
anon_umask=022
anon_world_readable_only=NO

# ローカルユーザー設定
local_enable=${LOCAL_ENABLE}
write_enable=${WRITE_ENABLE}
local_umask=022
chroot_local_user=YES
allow_writeable_chroot=YES
EOF

# ユーザーリスト設定（ローカルユーザーが有効な場合のみ）
if [ "${LOCAL_ENABLE}" = "YES" ]; then
    cat >> /etc/vsftpd/vsftpd.conf <<EOF

# ユーザーリスト
userlist_enable=YES
userlist_file=/etc/vsftpd/user_list
userlist_deny=NO
EOF
fi

# パッシブモード設定
cat >> /etc/vsftpd/vsftpd.conf <<EOF

# パッシブモード設定
pasv_enable=YES
pasv_min_port=${PASV_MIN_PORT}
pasv_max_port=${PASV_MAX_PORT}
EOF

# PASV_ADDRESSが設定されている場合
if [ -n "${PASV_ADDRESS}" ]; then
    echo "pasv_address=${PASV_ADDRESS}" >> /etc/vsftpd/vsftpd.conf
fi

# SSL設定
if [ "${SSL_ENABLE}" = "YES" ]; then
    cat >> /etc/vsftpd/vsftpd.conf <<EOF

# SSL/TLS設定
ssl_enable=YES
allow_anon_ssl=YES
force_anon_data_ssl=NO
force_anon_logins_ssl=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
require_ssl_reuse=NO
ssl_ciphers=HIGH
rsa_cert_file=/etc/ssl/private/vsftpd.pem
rsa_private_key_file=/etc/ssl/private/vsftpd.pem
pasv_promiscuous=YES
EOF

    # Implicit SSL（FTPS）の設定
    if [ "${IMPLICIT_SSL}" = "YES" ]; then
        cat >> /etc/vsftpd/vsftpd.conf <<EOF
implicit_ssl=YES
listen_port=990
EOF
    fi
fi

# ログ設定
cat >> /etc/vsftpd/vsftpd.conf <<EOF

# ログ設定
xferlog_enable=YES
xferlog_std_format=YES
log_ftp_protocol=YES
syslog_enable=NO
vsftpd_log_file=/var/log/vsftpd/vsftpd.log
xferlog_file=/var/log/vsftpd/xferlog

# その他の設定
dirmessage_enable=YES
use_localtime=YES
secure_chroot_dir=/var/empty
EOF

# PAM設定（ローカルユーザーが有効な場合のみ）
if [ "${LOCAL_ENABLE}" = "YES" ]; then
    echo "pam_service_name=vsftpd" >> /etc/vsftpd/vsftpd.conf
fi

echo "Configuration file generated at /etc/vsftpd/vsftpd.conf"
echo ""
echo "Starting vsftpd..."

# ログファイルを標準出力/エラー出力にリダイレクト（バックグラウンド）
touch /var/log/vsftpd/vsftpd.log /var/log/vsftpd/xferlog
tail -f /var/log/vsftpd/vsftpd.log /var/log/vsftpd/xferlog 2>&1 &

# vsftpdの起動
exec "$@"
