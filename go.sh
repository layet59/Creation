#!/bin/bash
set -euo pipefail

CODE="XZJyAV7Zgg40opXiOkL8loXyOuSRqhJgXqDV"
echo "============================================"
echo "  Clonage omalauncher -> Honor Magic 8 Pro"
echo "============================================"

read -rp "Mot de passe du clone : " PW </dev/tty
echo ""

echo "[1/5] Récupération du lien pCloud..."
DL_URL=$(python3 -c "
import json, urllib.request
d = json.loads(urllib.request.urlopen('https://eapi.pcloud.com/getpublinkdownload?code=$CODE', timeout=20).read())
if d.get('result') != 0: raise SystemExit('Erreur pCloud: ' + str(d))
print('https://' + d['hosts'][0] + d['path'])
")

echo "[2/5] Téléchargement du clone chiffré (36 Mo)..."
curl -fL --progress-bar "$DL_URL" -o /tmp/omalauncher-clone.tar.gz.enc

echo "[3/5] Déchiffrement et vérification..."
if ! openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 -in /tmp/omalauncher-clone.tar.gz.enc -out /tmp/omalauncher-clone.tar.gz -pass "pass:$PW"; then
  rm -f /tmp/omalauncher-clone.tar.gz.enc /tmp/omalauncher-clone.tar.gz
  echo "❌ Mot de passe incorrect !"
  exit 1
fi
rm -f /tmp/omalauncher-clone.tar.gz.enc

echo "[4/5] Sauvegarde de l'existant + extraction..."
if [ -d /root/.config/omalauncher ]; then
  tar czf /root/sauvegarde-avant-clone.tar.gz -C /root .config/omalauncher 2>/dev/null || true
fi
tar xzf /tmp/omalauncher-clone.tar.gz -C /root
rm -f /tmp/omalauncher-clone.tar.gz

chmod 700 /root/.secrets /root/.local/share/omalauncher-* 2>/dev/null || true
chmod 600 /root/.config/omalauncher/mail-accounts.json /root/.config/omalauncher/ai-keys.json \
  /root/.config/omalauncher/*.url /root/.config/rclone/rclone.conf /root/.secrets/* 2>/dev/null || true

echo "[5/5] Installation des paquets Arch & Python (rclone, pillow, openpyxl, domotique)..."
pacman -Sy --needed --noconfirm rclone python-pillow python-openpyxl python-numpy curl openssl

if [ ! -x /root/.local/share/omalauncher-tuya/venv/bin/python ]; then
  python3 -m venv /root/.local/share/omalauncher-tuya/venv
fi
/root/.local/share/omalauncher-tuya/venv/bin/pip install --quiet --upgrade pip
/root/.local/share/omalauncher-tuya/venv/bin/pip install --quiet \
  tinytuya tuya-device-sharing-sdk pyezviz PyJWT aiohttp requests qrcode pillow pydantic

python3 /root/.config/omalauncher/scripts/mail.py sync >/dev/null 2>&1 &
python3 /root/.config/omalauncher/scripts/immo.py sync >/dev/null 2>&1 &
bash /root/.config/omalauncher/scripts/veilles-sync.sh >/dev/null 2>&1 &

echo ""
echo "============================================"
echo "  ✅ CLONAGE TERMINÉ !"
echo "  Reviens sur l'accueil d'omalauncher :"
echo "  toutes tes pages arrivent en quelques secondes."
echo "============================================"
