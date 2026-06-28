# نشر TikZoom Bot Host على Railway 🚂

## ١) المتطلبات
- حساب على [Railway.app](https://railway.app) (تقدر تسجّل بـ GitHub).
- بوت تلجرام جاهز عندك (BOT_TOKEN من @BotFather).
- آيدي التلجرام بتاعك (من @userinfobot) عشان تكون أدمن.

## ٢) ارفع المشروع على GitHub (الأسهل)
```bash
cd bot-host
git init
git add .
git commit -m "first deploy"
git branch -M main
git remote add origin https://github.com/USERNAME/tikzoom.git
git push -u origin main
```

## ٣) إنشاء المشروع على Railway
1. افتح Railway → **New Project** → **Deploy from GitHub repo** → اختار الريبو.
2. Railway هيكتشف إنه Python ويبدأ يبني تلقائياً (Nixpacks).
3. روح على تبويب **Variables** وضيف كل المتغيرات اللي تحت 👇

## ٤) متغيرات البيئة المطلوبة (Variables)

| المتغير | القيمة |
|---|---|
| `BOT_TOKEN` | توكن البوت من BotFather |
| `ADMIN_IDS` | آيديك في تلجرام (لو أكتر من واحد افصل بفاصلة) |
| `WEBHOOK_SECRET` | أي نص طويل عشوائي (مثلاً ناتج `openssl rand -hex 32`) |
| `FERNET_KEY` | المفتاح اللي مولّدهولك تحت 👇 |
| `PUBLIC_BASE_URL` | الدومين اللي Railway هيديهولك (مثال: `https://tikzoom-production.up.railway.app`) |
| `DEFAULT_LANG` | `ar` |
| `DATA_DIR` | `/data` |
| `DB_PATH` | `/data/platform.db` |
| `BOTS_DIR` | `/data/bots_storage` |

**FERNET_KEY جاهز للنسخ:**
```
SyD-ABw3_ZjPOCq8DFSj4M7AfkrQ1Erg1BRCthFQqww=
```
(لو عاوز تولّد واحد بنفسك: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"`)

### اختياري — لو هتستخدم Firebase RTDB
- `FIREBASE_DB_URL` = رابط الـ Realtime DB بتاعك
- `FIREBASE_SERVICE_ACCOUNT_JSON` = الصق محتوى ملف الـ service account JSON كله (سطر واحد)

## ٥) ضيف Domain + Volume
1. في Railway → تبويب **Settings** → **Networking** → اضغط **Generate Domain**.
2. انسخ الدومين وحطّه قيمة لـ `PUBLIC_BASE_URL` في Variables.
3. تبويب **Settings** → **Volumes** → **+ New Volume** → Mount path: `/data`.
   ⚠️ مهم جداً عشان قاعدة البيانات SQLite متضيعش لما الكونتينر يعاد تشغيله.

## ٦) إعادة Deploy
بعد ما تخلّص الـ Variables والـ Volume، اضغط **Deploy** تاني (أو Push commit جديد على GitHub).

## ٧) اضبط الـ Webhook لبوتك الرئيسي
بعد ما الـ Deploy يخلّص، افتح المتصفّح وادخل (غيّر القيم):
```
https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=<PUBLIC_BASE_URL>/tg/main&secret_token=<WEBHOOK_SECRET>
```
لو طلعلك `"ok":true` يبقى تمام، بوتك شغّال على Railway.

## ⚠️ ملاحظات مهمة
- جزء **استضافة بوتات المستخدمين** (subprocess لكل بوت) مش هيشتغل كويس على خطة Railway مجانية لأن كل بوت بياخد بورت وذاكرة. يفضل تستخدم خطة Pro أو سيرفر VPS عادي للجزء ده.
- المنصة نفسها (المانجر بوت + الـ API + الـ Mini App) هتشتغل على Railway من غير مشاكل.
- لو ظهرت أخطاء في الـ Build، شوف الـ **Deploy logs** في Railway وقولّي.
