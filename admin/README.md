# ECE Admin (Flutter — Android / iOS / Web / Windows)

لوحة إدارة عربية (RTL) لبيانات شاشة ECE عبر PocketBase — أدوار **سوبر أدمن** و**أدمن**.

التطبيق يعمل على **نفس شبكة الـ Wi‑Fi** مع جهاز الشاشة، ويبحث تلقائياً عن السيرفر (UDP) فلا تحتاج تدخل الـ IP يدوياً في العادة.

## الأدوار

| | سوبر أدمن (`role=super`) | أدمن (`role=admin`) |
|---|---|---|
| الجداول / المراحل / الشعب / الشريط / الأساتذة / الإعلانات / الوسائط | نعم | نعم |
| إضافة/تعديل/حذف مشغّلين (`Admins`) | نعم | لا |
| عرض سجل النشاط (`AdminLogs`) | نعم | لا |

## اكتشاف السيرفر

1. شغّل `ECE-screen` على جهاز العرض (يفتح PocketBase على `:8090` + منارة اكتشاف UDP `:28090`).
2. وصّل الموبايل **لنفس الـ Wi‑Fi**.
3. افتح ECE Admin — يبحث تلقائياً ويعرض عنوان السيرفر عند إيجاده.
4. سجّل الدخول بحساب Admins.

إذا فشل البحث (جدار ناري يمنع UDP): زر **إدخال العنوان يدوياً** → `http://IP-الشاشة:8090`.

على ويندوز اسمح لتطبيق الشاشة بوارد UDP منفذ `28090` إن طلب الجدار الناري ذلك.

## بناء الموبايل

### Android

```bash
cd admin
flutter pub get
flutter build apk --release
flutter run -d android
```

### iOS (على Mac فقط)

مجلد `admin/ios/` موجود في المستودع (Xcode + `Podfile`). على الـ Mac:

```bash
git clone <repo-url>
cd <repo>/admin
flutter pub get
cd ios && pod install && cd ..
flutter run -d <iphone>          # جهاز موصول + Developer Mode
# أو:
open ios/Runner.xcworkspace      # Signing: اختر Team في Xcode ثم Run
```

تفاصيل إضافية: [`ios/README.md`](ios/README.md). Bundle ID: `edu.ece.eceAdmin`.

## أول تشغيل للحسابات

1. أنشئ PocketBase superuser إن لزم.
2. ادخل به مرة → أنشئ أول **سوبر أدمن** (أو `ECE_ADMIN_EMAIL` / `ECE_ADMIN_PASSWORD`).
3. من **المشغّلون** أضف حسابات أدمن.

## أمان

الوصول محلي على الشبكة فقط. استخدم كلمات مرور قوية لحسابات `Admins`.
