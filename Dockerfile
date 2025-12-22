FROM alpine:3.19

# vsftpdと必要なパッケージをインストール
RUN apk add --no-cache \
    vsftpd \
    openssl \
    shadow \
    bash

# FTPユーザーリストディレクトリ
RUN mkdir -p /etc/vsftpd

# FTP用のディレクトリ作成
RUN mkdir -p /var/ftp/pub && \
    chown -R ftp:ftp /var/ftp

# ログディレクトリ
RUN mkdir -p /var/log/vsftpd

# エントリーポイントスクリプトとPAM設定をコピー
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY pam_vsftpd /etc/pam.d/vsftpd
RUN chmod +x /usr/local/bin/entrypoint.sh

# FTPコントロールポート
EXPOSE 21

# パッシブモード用のポート範囲
EXPOSE 21100-21110

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["vsftpd", "/etc/vsftpd/vsftpd.conf"]
