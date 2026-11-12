# วิธีสร้างไฟล์ `.ipa` (ภาษาไทย) — ไม่ต้องมี Mac

> **สถานะตอนนี้:** โปรเจกต์แก้ให้รองรับทุก iOS แล้ว, มี Git commit ในเครื่องแล้ว, มี CI workflow แล้ว
> **แต่ยังไม่มีไฟล์ `.ipa` อยู่จริง** — ไฟล์จะเกิดขึ้นก็ต่อเมื่อ GitHub Actions รัน build บน macOS runner สำเร็จ
> ZIP `3105-all-ios-versions.zip` คือ "ชุดโปรเจกต์ + สคริปต์" ไม่ใช่ IPA สำเร็จรูป

## ภาพรวม

```
[1] สร้าง repo ว่างเปล่าบน GitHub
        ↓
[2] push โปรเจกต์ขึ้น main (สคริปต์ทำให้)
        ↓
[3] Actions รันบน macos-latest → ออก 3105-unsigned.ipa (artifact)
        ↓
[4] เซ็นด้วย enterprise cert → 3105-signed.ipa → ติดตั้ง
```

---

## 1. สร้าง GitHub repo แบบว่างเปล่า (คลิกบนเว็บ)

1. เปิด <https://github.com/new> แล้วล็อกอินบัญชี **ของคุณ**
2. **Owner** = บัญชีคุณ | **Repository name** = เช่น `3105-all-ios`
3. เลือก **Public** (Actions ฟรี) หรือ **Private** (ใช้ Actions minutes ตามแพ็กเกจ)
4. **สำคัญที่สุด: อย่าติ๊กช่องเหล่านี้เด็ดขาด**
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license

   ถ้า repo มี commit อยู่แล้ว คำสั่ง push ครั้งแรกจะถูกปฏิเสธ
5. กด **Create repository**
6. ในหน้าถัดไป GitHub จะโชว์ URL แบบ `https://github.com/<user>/3105-all-ios.git` — **ก็อปปี้ URL นี้ไว้** (ไม่ต้องรันคำสั่ง `git remote add ...` ที่ GitHub แนะนำ เพราะสคริปต์ทำให้แล้ว)

**ทางเลือกสำหรับคนที่ชอบ CLI** (ข้ามการคลิกเว็บได้เลย):

```bash
winget install --id GitHub.cli      # ติดตั้ง gh ครั้งแรก only
gh auth login                       # เลือก GitHub.com → HTTPS → Login with a web browser
gh repo create 3105-all-ios --private --source=. --remote=origin --push
```

ข้อนี้จะสร้าง repo + ตั้ง `origin` + push ให้ในคำสั่งเดียว (ข้าม `scripts/push-to-github.sh`)

---

## 2. Push โปรเจกต์ขึ้น GitHub

เปิด **Git Bash** (Windows) หรือ Terminal แล้วเข้าโฟลเดอร์โปรเจกต์:

```bash
cd /c/Users/Administrator/Desktop/3105-1.1.1      # ปรับตามตำแหน่งที่คุณแตก ZIP
./scripts/push-to-github.sh https://github.com/<user>/<repo>.git
```

- ถ้า Windows ถาม login → เลือก **Sign in with your browser** (Git Credential Manager)
- ถ้าจะใช้ PAT: GitHub → **Settings → Developer settings → Personal access tokens → Tokens (classic)** → Generate new token → ติ๊ก `repo` → วาง token **เฉพาะตอน prompt ถาม password** ห้ามวางในแชท / ไฟล์ / repo
- ถ้าขึ้น `error: push rejected` → repo ไม่ว่าง ให้ลบแล้วสร้างใหม่แบบข้อ 1 หรือรัน:
  ```bash
  git pull --rebase origin main && git push -u origin main
  ```
- สำเร็จจะเห็น `==> Done. Next:` ตามด้วย 4 บรรทัดถัดไป

สคริปต์จะเช็กก่อน commit ว่าไม่มี `.p12` / `.mobileprovision` / `.env` หลุดขึ้นไป และเช็กว่า workflow กับ build script ถูก track อยู่

---

## 3. ให้ CI สร้าง `3105-unsigned.ipa`

1. เปิด `https://github.com/<user>/<repo>/actions`
2. การ push ขึ้น `main` จะเริ่ม workflow **Build unsigned IPA** อัตโนมัติ (หรือกด **Actions → Build unsigned IPA → Run workflow** เองก็ได้)
3. กดเข้า run นั้น → รอประมาณ 5–15 นาที → ถ้าสถานะเขียว ให้เลื่อนลงหา **Artifacts**
4. โหลด **`3105-unsigned-ipa`** → แตก ZIP → ได้ **`3105-unsigned.ipa`**

| เรื่อง | คำตอบ |
|---|---|
| ต้องมี certificate ตอน build ไหม | ไม่ต้อง (`CODE_SIGNING_ALLOWED=NO`) |
| ต้องมี Mac ไหม | ไม่ต้อง GitHub ให้ `macos-latest` runner |
| artifact เก็บนานแค่ไหน | 14 วัน |
| ไฟล์นี้ติดตั้งได้เลยไหม | **ไม่ได้** ยังไม่เซ็น ต้องทำข้อ 4 |
| ถ้า run เป็นสีแดง | กดเข้าไปก็อปปี้ log error มาให้ช่วยแก้ (มักเป็นเรื่อง Xcode SDK / API ของ iOS ใหม่) |

---

## 4. เซ็น แล้วติดตั้ง

ต้องมี **enterprise certificate (`.p12` + รหัส)** และ **`.mobileprovision`** ที่ครอบ bundle ID `com.apple.mobile.MobileHouseArrest`

**บน iPhone — ง่ายสุด ไม่ต้องใช้คอม**

1. เอา `3105-unsigned.ipa`, `.p12`, `.mobileprovision` ใส่เครื่อง (Files / AirDrop)
2. เปิด **ESign** → import certificate/profile → เลือก IPA → **Sign** → **Install**

**บน Windows — ใช้ zsign**

```powershell
.\scripts\resign-windows-zsign.ps1 -Ipa .\3105-unsigned.ipa `
  -P12 .\enterprise.p12 -P12Password 'YOUR_PASSWORD' `
  -MobileProvision .\profile.mobileprovision
```

ได้ `3105-signed.ipa` แล้วติดตั้งผ่าน ESign, enterprise OTA (HTTPS + `itms-services` manifest), MDM หรือ Apple Configurator

> ⚠️ **ใบรับรอง enterprise สร้างเองไม่ได้** ต้องออกจากบัญชี **Apple Developer Enterprise Program** ที่องค์กรของคุณเป็นเจ้าของและคุณได้รับอนุญาตให้ใช้ อย่าใช้ใบรับรองของผู้อื่น และห้ามอัปโหลด `.p12` / รหัส / token ขึ้น GitHub หรือส่งในแชท
>
> Bundle ID `com.apple.mobile.MobileHouseArrest` เป็น ID ที่ Apple สงวนไว้ บัญชี developer ธรรมดามักสร้าง App ID ตรงกันไม่ได้ — นี่คือเหตุผลที่โปรเจกต์แจกเป็น unsigned IPA ให้ไป re-sign แทน

---

## สรุปสั้น ๆ

| อยาก "สร้าง" อะไร | ทำยังไง |
|---|---|
| GitHub repo | `github.com/new` → สร้าง **แบบว่างเปล่า** (หรือ `gh repo create ...`) |
| `3105-unsigned.ipa` | `./scripts/push-to-github.sh <url>` → Actions → artifact `3105-unsigned-ipa` |
| `3105-signed.ipa` | ESign บนเครื่อง หรือ `resign-windows-zsign.ps1` + ใบรับรอง enterprise ของคุณ |
| ติดตั้งบน iPhone | ESign / enterprise OTA / MDM / Apple Configurator |

โปรเจกต์ไม่รองรับ SideStore, AltStore, 3uTools และ LiveContainer
