# ECE Admin (Flutter — Android / iOS / Web / Windows)

لوحة إدارة عربية (RTL) لبيانات شاشة ECE عبر PocketBase — أدوار **سوبر أدمن** و**أدمن**، مع دعم التعديل **من خارج شبكة الكلية** عبر رابط نفق (tunnel).

## الأدوار

| | سوبر أدمن (`role=super`) | أدمن (`role=admin`) |
|---|---|---|
| الجداول / المراحل / الشعب / الشريط / الأساتذة / الإعلانات / الوسائط | نعم | نعم |
| إضافة/تعديل/حذف مشغّلين (`Admins`) | نعم | لا |
| عرض سجل النشاط (`AdminLogs`) | نعم | لا |

## كيف يتصل الموبايل بالشاشة؟

التطبيق لا يخزّن البيانات داخله — يتصل بـ PocketBase على جهاز الشاشة (`:8090`).

| الوضع | عنوان السيرفر في شاشة الدخول |
|---|---|
| نفس الـ Wi‑Fi | `http://IP-جهاز-الشاشة:8090` |
| من البيت / بيانات الموبايل (خارج الشبكة) | رابط HTTPS من Cloudflare Tunnel مثل `https://….trycloudflare.com` |

### تفعيل التعديل عن بُعد (موصى به)

1. شغّل `ECE-screen` على جهاز العرض.
2. على **نفس الجهاز** شغّل النفق:

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File scripts\windows\remote-tunnel.ps1
```

```bash
# Linux
./scripts/remote-tunnel.sh
```

3. انسخ الرابط `https://….trycloudflare.com` الذي يطبعه `cloudflared`.
4. في تطبيق ECE Admin على الأندرويد/الآيفون الصق الرابط في **عنوان السيرفر** وسجّل الدخول.

الرابط العشوائي يتغيّر كل مرة تشغّل فيها الـ quick tunnel. لرابط ثابت استخدم Cloudflare **named tunnel** وعيّن `ECE_PUBLIC_URL` — انظر [`docs/operations.md`](../docs/operations.md).

بدائل: Tailscale/ZeroTier (الموبايل وجهاز الشاشة على شبكة افتراضية واحدة استخدم IP الـ 100.x).

## بناء الموبايل

```bash
cd admin
flutter pub get

# Android APK / App Bundle
flutter build apk --release
# flutter build appbundle --release

# iOS (يحتاج Mac + Xcode)
flutter build ios --release
```

تشغيل للتطوير:

```bash
flutter run -d android
flutter run -d ios
flutter run -d chrome
flutter run -d windows
```

## أول تشغيل للحسابات

1. أنشئ PocketBase superuser إن لزم.
2. ادخل به مرة واحدة → أنشئ أول **سوبر أدمن** (أو عيّن `ECE_ADMIN_EMAIL` / `ECE_ADMIN_PASSWORD` قبل إقلاع الشاشة).
3. من **المشغّلون** أضف حسابات أدمن.

## أمان

- فضّل دائماً رابط **HTTPS** للنفاذ من الإنترنت؛ لا تفتح المنفذ 8090 مباشرة على الراوتر بدون حماية.
- أوقف سكربت الـ tunnel عندما لا تحتاجه.
- كلمات مرور قوية لحسابات `Admins`.
