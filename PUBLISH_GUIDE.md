# دليل النشر التلقائي — بوابة الجحيم / Gateway to Hell

## المحتويات

- [ما هو publish.py؟](#ما-هو-publishpy)
- [المتطلبات](#المتطلبات)
- [إعداد Roblox API Key](#إعداد-roblox-api-key)
- [تثبيت الأدوات](#تثبيت-الأدوات)
- [إعداد المتغيرات](#إعداد-المتغيرات)
- [تخصيص الريبو قبل النشر](#تخصيص-الريبو-قبل-النشر)
- [الاستخدام](#الاستخدام)
- [كيف يعمل البناء](#كيف-يعمل-البناء)
- [استكشاف الأخطاء](#استكشاف-الأخطاء)

## ما هو publish.py؟

هذا السكربت يشغّل pipeline تلقائي من 5 خطوات:

```text
Lint → Build → Validate XML → Strip XML Declaration → Upload
```

الفكرة هي أن الريبو يبقى هو مصدر الحقيقة، وملف اللعبة الكامل يُعاد توليده كل مرة من `src/`.

## المتطلبات

- Python 3.8+
- `selene`
- `luau-analyze` اختياري
- Roblox API Key للنشر

## إعداد Roblox API Key

من لوحة Roblox Open Cloud / Credentials أنشئ key بصلاحية الكتابة على الـ experience الخاصة بالمشروع.

ثم خزّنه كمتغير بيئة:

```bash
export ROBLOX_PUBLISH_API_KEY="your-key-here"
```

## تثبيت الأدوات

إذا لم تكن مثبتة، ثبّت:

- `selene`
- `luau-analyze` إن أردت التحليل الإضافي

بعدها تحقق:

```bash
selene --version
luau-analyze --version
python3 --version
```

## إعداد المتغيرات

### الطريقة السريعة

```bash
export ROBLOX_PUBLISH_API_KEY="your-api-key"
python3 publish.py --lint-only
```

## تخصيص الريبو قبل النشر

افتح `publish.py` إذا كنت تستهدف تجربة أخرى، وعدّل القيم الرقمية الحالية لـ `UNIVERSE_ID` و `PLACE_ID` هناك. القيم الموجودة في الملف مضبوطة بالفعل على تجربة بوابة الجحيم الحالية.

## الاستخدام

### فحص فقط

```bash
python3 publish.py --lint-only
```

### بناء الملف

```bash
python3 build_all.py
```

### نشر كامل

```bash
python3 publish.py
```

### نشر بدون lint

```bash
python3 publish.py --skip-lint
```

## كيف يعمل البناء؟

`build_all.py` يقوم بما يلي:

1. يقرأ ملفات `src/`
2. يضع كل Script تحت الخدمة المناسبة
3. يدمج `templates/workspace.xml`
4. يدمج `templates/lighting.xml`
5. يولّد `GatewayToHell.rbxlx`

هذا الأسلوب greenfield:

- لا يعتمد على تعديل ملف place قديم
- لا يحتاج marker injection داخل نسخة سابقة
- يعيد بناء المكان كاملًا كل مرة

## ملاحظات فنية

- `GatewayToHell.rbxlx` هو الملف النهائي الذي يرفعه Roblox Open Cloud
- لو بدا الملف يبدأ بـ `<?xml ...?>` فسيتم حذف هذا السطر قبل الرفع
- `selene` مضبوط على `std = "roblox"` حتى لا يظهر ضجيج globals الخاصة بروبلوكس

## استكشاف الأخطاء

### المشكلة: lint يفشل

افحص رسائل `selene` و `luau-analyze`.

### المشكلة: النشر يفشل

تحقق من:

- أن `ROBLOX_PUBLISH_API_KEY` موجود
- أن `UNIVERSE_ID` و `PLACE_ID` مضبوطان على التجربة الحالية، أو حدّثهما في `publish.py` إذا كنت تستهدف تجربة أخرى
- أن API key لديه صلاحية الكتابة

### المشكلة: build يفشل

تأكد أن كل ملفات `src/` موجودة وأن `templates/` تحتوي:

- `workspace.xml`
- `lighting.xml`
