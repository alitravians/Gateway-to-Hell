# دليل المطورين — Gateway to Hell

هذا الملف مخصص لأي مطوّر جديد يستلم المشروع لاحقًا.

## هدف الريبو

هذا الريبو هو تجربة Roblox co-op horror باسم:

**بوابة الجحيم — Gateway to Hell**

الهدف المرحلي الحالي:

1. تجهيز pipeline النشر
2. تجهيز scaffolding أساسي
3. إبقاء اللوبي قابلًا للعب
4. ترك كل تصميم بصري كبير لمرحلة Blender القادمة

## الملفات المهمة

- `build_all.py`
  - يولد `GatewayToHell.rbxlx` من `src/`
- `publish.py`
  - ينفذ 5 خطوات: lint → build → validate → strip → upload
- `src/`
  - كل Luau source
- `templates/`
  - XML جاهز لـ Workspace و Lighting

## ترتيب التشغيل

### 1) lint

يفحص:

- `selene`
- `luau-analyze` إن كان موجودًا

### 2) build

`build_all.py` يقرأ `src/` ويجمع place كاملًا جديدًا.

هذا أهم فرق عن المشاريع التي تعدّل ملف place الموجود داخل الملف نفسه.

### 3) validate

يتأكد أن `GatewayToHell.rbxlx` XML صحيح.

### 4) strip

لو كان الملف يحتوي XML declaration في البداية، يتم حذفها لأن Roblox Open Cloud لا يحبها.

### 5) upload

يرفع الملف إلى Roblox Open Cloud.

## إعداد النشر

في `publish.py`:

- عيّن `UNIVERSE_ID`
- عيّن `PLACE_ID`

القيم الحالية في `publish.py` مضبوطة بالفعل على تجربة Gateway to Hell الحالية. إذا كنت ستنشر إلى تجربة أخرى فقط، فحدّث `UNIVERSE_ID` و `PLACE_ID` هناك.

## معايير Luau

- استخدم `local` دائمًا
- خزّن الوصول إلى DataStore داخل `pcall`
- لا تثق في البيانات القادمة من العميل
- أنشئ `RemoteEvent`s على السيرفر قبل الاعتماد عليها

## قواعد Roblox UI

الواجهات الحالية خفيفة ومؤقتة:

- Loading screen
- Main menu
- Matchmaking overlay

التصميم النهائي سيُعاد بناءه لاحقًا بعد اعتماد render البلندر.

## Blender pipeline

كل عنصر بصري رئيسي في الخريطة يجب أن يمر بهذه السلسلة:

`Blender → FBX → Upload → InsertService:LoadAsset`

### ماذا يعني ذلك عمليًا؟

- لا نبني props الكبيرة بـ Parts عشوائية
- نستخدم Parts فقط للـ anchors أو placeholders
- أي mesh نهائي يجب أن يكون قابلًا لإعادة التصدير والاستبدال بسهولة

## إضافة ميزة جديدة

إذا كنت ستضيف feature جديدة:

1. حدّد هل هي server أو client أو shared
2. أضف السكربت في `src/`
3. حدّث `build_all.py` إذا احتجت class/service جديد
4. شغّل lint
5. أعد توليد `GatewayToHell.rbxlx`

## اختبار التغييرات

```bash
python3 build_all.py
python3 publish.py --lint-only
python3 -c "import xml.etree.ElementTree as ET; ET.parse('GatewayToHell.rbxlx')"
```

## ملاحظات مهمة

- هذا الريبو غير مكتمل عمدًا في هذه المرحلة
- لا تبدأ ببناء الأنظمة النهائية قبل اعتماد الـ visual direction
- أي تغيير بصري كبير يجب أن ينسجم مع هوية الرعب الداكنة
