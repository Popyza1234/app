# วิธีสร้างไฟล์ `.ipa` (ภาษาไทย) — ไม่ต้องมี Mac

> **สถานะตอนนี้:** โปรเจกต์ถูกออกแบบใหม่เป็น **dekpop** (มีแค่ฟีเจอร์ Files) และ push ขึ้น GitHub แล้ว → GitHub Actions จะ build ไฟล์ `.ipa` ให้
> **ไฟล์ที่ได้คือ `dekpop-unsigned.ipa` (ยังไม่ได้เซ็น)** — ต้องเซ็นด้วยใบรับรอง enterprise ของคุณก่อนติดตั้ง
> ZIP `dekpop-source.zip` คือ "ชุดโปรเจกต์ + สคริปต์" ไม่ใช่ IPA สำเร็จรูป
> ชื่อ target ใน Xcode ยังเป็น `3105` แต่ `PRODUCT_NAME` เป็น `dekpop` → ได้ `Payload/dekpop.app/`

## ภาพรวม

```
[1] สร้าง repo ว่างเปล่าบน GitHub
        ↓
[2] push โปรเจกต์ขึ้น main (สคริปต์ทำให้)
        ↓
[3] Actions รันบน macos-latest → ออก dekpop-unsigned.ipa (artifact)
        ↓
[4] เซ็นด้วย enterprise cert → dekpop-signed.ipa → ติดตั้ง
```

---

## 1. สร้าง GitHub repo แบบว่างเปล่า (คลิกบนเว็บ)

1. เปิด <https://github.com/new> แล้วล็อกอินบัญชี **ของคุณ**
2. **Owner** = บัญชีคุณ | **Repository name** = เช่น `dekpop-app`
3. เลือก **Public** (Actions ฟรี) หรือ **Private** (ใช้ Actions minutes ตามแพ็กเกจ)
4. **สำคัญที่สุด: อย่าติ๊กช่องเหล่านี้เด็ดขาด**
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license

   ถ้า repo มี commit อยู่แล้ว คำสั่ง push ครั้งแรกจะถูกปฏิเสธ
5. กด **Create repository**
6. ในหน้าถัดไป GitHub จะโชว์ URL แบบ `https://github.com/<user>/dekpop-app.git` — **ก็อปปี้ URL นี้ไว้** (ไม่ต้องรันคำสั่ง `git remote add ...` ที่ GitHub แนะนำ เพราะสคริปต์ทำให้แล้ว)

**ทางเลือกสำหรับคนที่ชอบ CLI** (ข้ามการคลิกเว็บได้เลย):

```bash
winget install --id GitHub.cli      # ติดตั้ง gh ครั้งแรก only
gh auth login                       # เลือก GitHub.com → HTTPS → Login with a web browser
gh repo create dekpop-app --private --source=. --remote=origin --push
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

### ถ้าขึ้น `could not read Username` / `Authentication failed`

นี่คือ **เครื่องยังไม่ได้ล็อกอิน GitHub** — สคริปต์/ผู้ช่วยไม่สามารถล็อกอินแทนคุณได้ และ **ไม่ควรส่ง token มาในแชทเด็ดขาด**

**ง่ายสุด (แนะนำ):** ดับเบิลคลิก **`scripts\push-now.cmd`** (หรือรันจาก `cmd`) ตัวนี้จะเรียก `git push -u origin main` แบบที่อนุญาตให้หน้าต่างล็อกอินโผล่ได้ → กด **Sign in with your browser** แล้วล็อกอินบัญชี GitHub ของคุณ หลังจากนั้น Git Credential Manager จะจำไว้ ครั้งหน้าไม่ต้องทำซ้ำ

หรือพิมพ์เองใน Git Bash / Command Prompt:

```bash
git push -u origin main
```

ถ้าจะใช้ PAT: GitHub → **Settings → Developer settings → Personal access tokens → Tokens (classic)** → ติ๊ก `repo` → วาง token เป็น **password ตอน prompt** เท่านั้น (ห้ามวางในแชท / ไฟล์ / repo)

> `origin` ถูกตั้งเป็น URL ที่คุณให้ไว้แล้ว และ branch `main` มี commit พร้อม push อยู่ — เหลือแค่ผ่านการล็อกอินเท่านั้น ถ้าขึ้น `push rejected` แปลว่า repo ไม่ว่าง ให้ทำตามข้อ `git pull --rebase origin main` ด้านบน หรือลบ repo แล้วสร้างใหม่แบบข้อ 1

### ถ้าขึ้น `[ERROR] No remote given and 'origin' is not configured yet.`

**สาเหตุ:** คุณเปิด `push-now.cmd` จาก **ก๊อปปี้ที่อยู่นอกโฟลเดอร์โปรเจกต์** (เช่น ไฟล์จากการ์ดในแชท หรือแตก ZIP ไว้ที่อื่น) จึงไม่เจอ `.git` และ `origin` — สคริปต์เวอร์ชันเก่าจะหยุดตรงนี้

**แก้แล้วในเวอร์ชันปัจจุบัน** `push-now.cmd` ตอนนี้:

- มี `DEFAULT_REPO` = URL repo ของคุณอยู่ในตัว (ดับเบิลคลิกได้เลย ไม่ต้องพิมพ์ argument)
- ถ้าไม่เจอไฟล์โปรเจกต์ข้าง ๆ จะ **สลับไปใช้** `%USERPROFILE%\Desktop\3105-1.1.1` อัตโนมัติ
- ถ้าไม่มี `.git` จะ `git init -b main` → stage → ตรวจ secret → commit → ตั้ง `origin` ให้เอง (ไม่ต้องง้อ Git Bash)
- หา `git.exe` จาก `C:\Program Files\Git\cmd` เองถ้าไม่อยู่ใน PATH

**วิธีที่เร็วที่สุด** — เปิด Git Bash แล้วพิมพ์บรรทัดเดียว (โฟลเดอร์โปรเจกต์มี `origin` + commit ครบแล้ว):

```bash
cd /c/Users/Administrator/Desktop/3105-1.1.1 && git push -u origin main
```

หรือดับเบิลคลิก **ไฟล์ตัวที่อยู่ในโฟลเดอร์โปรเจกต์จริง**:

```
C:\Users\Administrator\Desktop\3105-1.1.1\scripts\push-now.cmd
```

จากนั้นกด **Sign in with your browser** เมื่อหน้าต่างล็อกอินโผล่

---

## 3. ให้ CI สร้าง `dekpop-unsigned.ipa`

1. เปิด `https://github.com/<user>/<repo>/actions`
2. การ push ขึ้น `main` จะเริ่ม workflow **Build unsigned IPA** อัตโนมัติ (หรือกด **Actions → Build unsigned IPA → Run workflow** เองก็ได้)
3. กดเข้า run นั้น → รอประมาณ 5–15 นาที → ถ้าสถานะเขียว ให้เลื่อนลงหา **Artifacts**
4. โหลด **`dekpop-unsigned-ipa`** → แตก ZIP → ได้ **`dekpop-unsigned.ipa`**

| เรื่อง | คำตอบ |
|---|---|
| ต้องมี certificate ตอน build ไหม | ไม่ต้อง (`CODE_SIGNING_ALLOWED=NO`) |
| ต้องมี Mac ไหม | ไม่ต้อง GitHub ให้ `macos-latest` runner |
| artifact เก็บนานแค่ไหน | 14 วัน |
| ไฟล์นี้ติดตั้งได้เลยไหม | **ไม่ได้** ยังไม่เซ็น ต้องทำข้อ 4 |
| ถ้า run เป็นสีแดง | กดเข้าไปก็อปปี้ log error มาให้ช่วยแก้ (มักเป็นเรื่อง Xcode SDK / API ของ iOS ใหม่) |
| run ถูก **cancelled** หลังค้างคิว ~15 นาที และไม่มี log ของ step เลย | GitHub หา macOS runner ไม่ได้ชั่วคราว (**ไม่ใช่โค้ดพัง**) → กด **Re-run jobs** หรือ **Actions → Run workflow** ใหม่สักรอบ |

### ✅ ประวัติ build

- **รุ่น 3105 เดิม (ก่อนรีแบรนด์):** Actions run [#43250078558](https://github.com/Popyza1234/app/actions/runs/43250078558) **success ทุก step** — Checkout, Show toolchain, Build unsigned IPA, Verify IPA layout, Upload artifact
  - artifact `3105-unsigned-ipa` = 3,268,242 bytes → ไฟล์ `3105-unsigned.ipa` 3,277,941 bytes
  - เวอร์ชัน `1.1.1 (7)` | `MinimumOSVersion 16.0` | **ยังไม่ได้เซ็น**
- **รุ่น dekpop 4.0.0 (ปัจจุบัน):** ทุกครั้งที่ push ขึ้น `main` workflow จะ build ใหม่ → artifact **`dekpop-unsigned-ipa`** → ไฟล์ **`dekpop-unsigned.ipa`**
  - `Payload/dekpop.app/` | แสดงชื่อ `dekpop` | เวอร์ชัน `4.0.0 (34)` | `MinimumOSVersion 16.0` | **ยังไม่ได้เซ็น**
  - Bundle ID ยังเป็น `com.apple.mobile.MobileHouseArrest` (จำเป็นสำหรับ MHA-C2 / ฟีเจอร์ Files)
- การที่ CI ขึ้นเขียวแปลว่าโค้ดที่แก้ **ถูก compile จริงบน Xcode ของ GitHub** ไม่ใช่แค่แก้ไฟล์ในเครื่อง
- **รุ่น 3.0.0 — เบาขึ้น เร็วขึ้น ลื่นขึ้น:** พื้นหลังทั้งหมดเป็นภาพนิ่ง ไม่มี Canvas 30 fps, อนุภาค, mesh เบลอ หรือ `repeatForever` อีกต่อไป ตัวเลือกหมวดในหน้า Files เป็นคอนโทรลใหม่ที่ล้นจอไม่ได้ ช่องค้นหาเป็นแคปซูลเบา ลิสต์จำกัดความกว้าง 760 pt และจัดกึ่งกลาง แถบเครื่องมือรวมเหลือเมนูเดียว ปุ่มแท็บ และเมนูเพิ่มเติม ไอคอนแอปโหลดผ่านคิวเดียว แถวไฟล์สูง 52 pt การค้นหาแอปอัปเดตไม่เกินหนึ่งครั้งต่อ 24 แอปใหม่ และ kernel exploit เริ่มหลังเฟรมแรก 0.8 วินาที ประกาศแสดงครั้งเดียวต่อประกาศ และนำฟีเจอร์ Asset Sets ออกแล้วโดยทางลัดโฟลเดอร์ยังอยู่
- **รุ่น 2.1.0 — รองรับ 27.0.1 + ไฟล์ที่เปิดได้เสมอ:** การ์ดหน้า Files แสดง **iOS 27.0.1 · รองรับ** และไม่มีข้อความ "ยังไม่รองรับ" อีก ถ้าเข้าคอนเทนเนอร์แอปไม่ได้บนเคอร์เนลใหม่ ให้กด **เปิด Documents ของ dekpop** หรือ **เลือกโฟลเดอร์…** (ตัวเลือกไฟล์ของระบบ เก็บเป็น security-scoped bookmark) เพื่อเปิดไฟล์ได้จริงโดยไม่ต้องใช้ช่องโหว่ และกด **ตรวจสอบความเข้ากันได้** เพื่อดูทีละชั้นว่าอันไหนล้มเหลว พร้อมปุ่มคัดลอกรายงาน
- **รุ่น 2.0.0 — เข้าถึงไฟล์ได้ทุก iOS:** iOS 27 ขึ้นไปเปิด Files ได้เหมือนรุ่นเก่าแล้ว ลบการแยกแบบ `iOS >= 26` ออก ทุกเวอร์ชันใช้ชุดเข้าถึงเดียวกัน (อ่านตรง → MCM → ขอสิทธิ์ → inode/metadata) และ sandbox escape ที่ไม่สำเร็จไม่ปิด Files อีกต่อไป; ดูข้อความ **เข้าถึงไฟล์แบบสากล · ทุกเวอร์ชัน iOS** ได้ที่การ์ดด้านบนของหน้า Files
- **รุ่น 1.5.0 — แท็บหมวดหมู่:** หน้าแรกมีแถบเลือก **แอป / ทางลัด / มอด** ไม่ต้องเลื่อนหา
- **หน้าเปิดแอป + ประกาศ:** ตอนเข้าแอปมีหน้าโหลดไล่สีสวยพร้อมแถบโหลด และการ์ดประกาศพร้อมรูปภาพที่แสดงทุกครั้งที่เข้าแอป พร้อมไอคอนแอพใหม่
- **ทางลัดโฟลเดอร์:** กดค้างที่โฟลเดอร์ใน Files → **เพิ่มทางลัด** (หรือใช้ **เพิ่มทางลัด** ในเมนู +) ทางลัดจะเปิดโฟลเดอร์นั้นทันที และแก้ไข/ลบได้จากแท็บทางลัด
- **คัดลอกที่อยู่ไฟล์:** กดค้างที่ไฟล์หรือโฟลเดอร์ → **คัดลอกพาธ** แล้ววางในช่องทางลัดด้วยปุ่ม **วาง** ตัวแก้ไขจะแยกคอนเทนเนอร์ให้อัตโนมัติ (เช่น `Documents/contentcache/Optional/ios/optionalavatare/gameassetbundles`)
- **มอดสองเว็บ:** KenModz (kenmodz.com) และ Cheat iOS VIP (mods.cheatiosvip.net) เปิดในเบราว์เซอร์ของแอป รักษาคุกกี้และเซสชัน มีปุ่มย้อนกลับ/ไปข้างหน้า/หน้าแรก/โหลดใหม่ และเปิดใน Safari ได้
- **นำศูนย์ดาวน์โหลดออก:** เซ็ตไฟล์ยังใช้ได้จากปุ่มรูปกล่องบน toolbar และใช้ขั้นตอนการใช้เซ็ตเดิม
- **รุ่น 1.3.0 รองรับ 2 ภาษา:** English และ ไทย (สลับได้จากไอคอนรูปโลกใน toolbar หรือตัวเลือก `English / ไทย` ด้านบนหน้า Files) ใน IPA จะมีแค่ `en.lproj` กับ `th.lproj` และ `CFBundleLocalizations = (en, th)`

**โหลดซ้ำในอนาคต** (artifact หมดอายุ 14 วัน) — ดับเบิลคลิก `scripts\download-unsigned-ipa.cmd` หรือ:

```bash
python scripts/download-unsigned-ipa.py
```

สคริปต์ใช้ credential ที่ Git Credential Manager เก็บไว้ในเครื่อง (ไม่พิมพ์ token ออกมา) หา run ล่าสุดที่ success แล้วแตก ZIP ใส่ `.ipa` ลง root พร้อมตรวจ Info.plist ให้ หรือโหลดเองที่ `https://github.com/Popyza1234/app/actions` → เลือก run → **Artifacts**

---

## 4. เซ็น แล้วติดตั้ง

ต้องมี **enterprise certificate (`.p12` + รหัส)** และ **`.mobileprovision`** ที่ครอบ bundle ID `com.apple.mobile.MobileHouseArrest`

**บน iPhone — ง่ายสุด ไม่ต้องใช้คอม**

1. เอา `dekpop-unsigned.ipa`, `.p12`, `.mobileprovision` ใส่เครื่อง (Files / AirDrop)
2. เปิด **ESign** → import certificate/profile → เลือก IPA → **Sign** → **Install**

**บน Windows — ใช้ zsign**

```powershell
.\scripts\resign-windows-zsign.ps1 -Ipa .\dekpop-unsigned.ipa `
  -P12 .\enterprise.p12 -P12Password 'YOUR_PASSWORD' `
  -MobileProvision .\profile.mobileprovision
```

ได้ `dekpop-signed.ipa` แล้วติดตั้งผ่าน ESign, enterprise OTA (HTTPS + `itms-services` manifest), MDM หรือ Apple Configurator

> ⚠️ **ใบรับรอง enterprise สร้างเองไม่ได้** ต้องออกจากบัญชี **Apple Developer Enterprise Program** ที่องค์กรของคุณเป็นเจ้าของและคุณได้รับอนุญาตให้ใช้ อย่าใช้ใบรับรองของผู้อื่น และห้ามอัปโหลด `.p12` / รหัส / token ขึ้น GitHub หรือส่งในแชท
>
> Bundle ID `com.apple.mobile.MobileHouseArrest` เป็น ID ที่ Apple สงวนไว้ บัญชี developer ธรรมดามักสร้าง App ID ตรงกันไม่ได้ — นี่คือเหตุผลที่โปรเจกต์แจกเป็น unsigned IPA ให้ไป re-sign แทน

---

## สรุปสั้น ๆ

| อยาก "สร้าง" อะไร | ทำยังไง |
|---|---|
| GitHub repo | `github.com/new` → สร้าง **แบบว่างเปล่า** (หรือ `gh repo create ...`) |
| `dekpop-unsigned.ipa` | `./scripts/push-to-github.sh <url>` → Actions → artifact `dekpop-unsigned-ipa` |
| push ติดล็อกอิน | ดับเบิลคลิก `scripts\push-now.cmd` → **Sign in with your browser** |
| ขึ้น `No remote given` | ใช้ `push-now.cmd` ตัวใหม่ หรือ `cd /c/Users/Administrator/Desktop/3105-1.1.1 && git push -u origin main` |
| `dekpop-signed.ipa` | ESign บนเครื่อง หรือ `resign-windows-zsign.ps1` + ใบรับรอง enterprise ของคุณ |
| ติดตั้งบน iPhone | ESign / enterprise OTA / MDM / Apple Configurator |

โปรเจกต์ไม่รองรับ SideStore, AltStore, 3uTools และ LiveContainer
