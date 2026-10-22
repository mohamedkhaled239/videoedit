# تقرير إعادة تنفيذ تطبيق Velo باستخدام Flutter

## 1. الهدف من التقرير

هذا المستند يحول التطبيق الحالي المكتوب بـ Swift/SwiftUI إلى مواصفات تنفيذ واضحة لمشروع Flutter. الهدف هو الوصول إلى نفس السلوك الوظيفي، وليس نسخ شكل الواجهات فقط.

المشروع الحالي تطبيق موبايل لتحرير وإدارة وتنزيل الوسائط، ويعتمد على المعالجة المحلية على الجهاز في أغلب الوظائف. لا يوجد Backend خاص بالتطبيق داخل المستودع، ولا توجد خدمة ذكاء اصطناعي خارجية. الاتصالات الخارجية الأساسية هي Firebase Firestore وRapidAPI وGoogle AdMob وروابط تنزيل الوسائط.

---

## 2. ملخص المنتج

اسم التطبيق الحالي: **Velo**.

الوظائف الأساسية:

1. تنزيل ملفات مباشرة أو فيديوهات سوشيال ميديا.
2. إنشاء مشروع فيديو من عدة مقاطع.
3. قص المقاطع وتغيير سرعتها وصوتها واتجاهها.
4. إضافة فلتر وموسيقى وتغيير أبعاد الفيديو.
5. ضغط الفيديو أو تحويل صيغته.
6. استخراج الصوت أو إنشاء GIF أو استخراج إطارات.
7. تعديل الصور وحفظها بصيغ مختلفة.
8. حفظ كل النتائج داخل مكتبة محلية في التطبيق.
9. تصدير الملفات إلى Photos أو Files.
10. مساعد محلي قائم على الكلمات والقواعد، بدون API ذكاء اصطناعي.
11. إعلانات Banner وNative وInterstitial يتم تشغيلها أو تعطيلها عن بعد.
12. دعم العربية والإنجليزية والوضع الفاتح والداكن.

مبدأ الخصوصية الأساسي: الفيديوهات والصور والمحادثات تتم معالجتها محليًا ولا تُرفع إلى خادم التطبيق. الاستثناء هو رابط السوشيال الذي يرسله المستخدم إلى خدمة RapidAPI للحصول على رابط الميديا.

---

## 3. خريطة الشاشات والتنقل

### 3.1 بدء التطبيق

تدفق التشغيل:

```text
Splash لمدة لا تقل عن ثانيتين
        |
        +-- تهيئة Firebase
        +-- قراءة Remote Settings من Firestore
        +-- تهيئة حالة إعلانات AdMob
        +-- تنظيف مجلد الملفات المؤقتة
        |
        v
هل وافق المستخدم على الشروط؟
        |
        +-- لا --> Onboarding
        |
        +-- نعم --> Main Tabs
```

### 3.2 التبويبات الرئيسية

```text
Download | Create | Library | Settings | Studio
```

- **Download:** لصق رابط وتنزيله.
- **Create:** محرر فيديو وأدوات سريعة وImage Lab.
- **Library:** ملفات التطبيق المحلية.
- **Settings:** الإعدادات والتخزين والخصوصية.
- **Studio:** مساعد محلي واقتراحات captions وأفكار.

---

## 4. الـ APIs والـ Endpoints

## 4.1 Firebase Firestore

يقرأ التطبيق مستند إعدادات واحدًا عند بدء التشغيل:

```text
Firebase project: videtor-4c5f1
Collection: vd-config
Document: config
Logical path: vd-config/config
```

شكل المستند المتوقع:

```json
{
  "enableVideoDownload": true,
  "rapidApiBaseUrl": "https://example-api-host",
  "rapidApiHost": "example-api-host.p.rapidapi.com",
  "rapidApiKey": "REDACTED",
  "enableAds": true
}
```

القيم الافتراضية عند فشل Firestore أو غياب أي قيمة:

```text
enableVideoDownload = false
enableAds = false
RapidAPI resolver = disabled
```

في Flutter يستخدم `firebase_core` للتهيئة و`cloud_firestore` لتنفيذ ما يعادل:

```dart
final snapshot = await FirebaseFirestore.instance
    .collection('vd-config')
    .doc('config')
    .get();
```

مهم: التطبيق الحالي يجلب الإعدادات مرة واحدة أثناء الإقلاع، ولا يستمع إلى تحديثات لحظية.

## 4.2 RapidAPI Social Resolver

الـ endpoint:

```http
POST {rapidApiBaseUrl}/v1/social/autolink
```

Headers:

```http
Content-Type: application/json
x-rapidapi-key: {rapidApiKey}
x-rapidapi-host: {rapidApiHost}
```

Body:

```json
{
  "url": "https://social-platform.example/post/..."
}
```

الاستجابة المتوقعة:

```json
{
  "thumbnail": "https://cdn.example/thumbnail.jpg",
  "medias": [
    {
      "url": "https://cdn.example/video.mp4",
      "quality": "720p",
      "extension": "mp4",
      "type": "video"
    }
  ],
  "error": false
}
```

النموذج المطلوب في Flutter:

```dart
class ResolvedMedia {
  final String label;
  final Uri url;
  final String kind;
  final String? fileExtension;
  final Uri? thumbnail;
}
```

قواعد تجهيز `label`:

- دمج `type` و`quality` بالشكل `Video · 720p`.
- عدم تكرار الجودة إذا كانت مساوية للنوع.
- استخدام اسم عام للملف إذا لم توجد القيمتان.

لا يعمل resolver إلا إذا كان مفتاح التفعيل true وكانت `baseUrl` و`host` و`apiKey` كلها موجودة.

## 4.3 تنزيل الملفات

إذا كان الرابط مباشرًا، أو بعد الحصول على رابط من RapidAPI، ينفذ التطبيق:

```http
GET {mediaUrl}
```

مع User-Agent يشبه Safari على iPhone لأن بعض شبكات CDN ترفض الطلب بدون User-Agent.

الامتدادات التي يعتبرها التطبيق روابط مباشرة:

```text
mp4, mov, m4v, m4a, wav, mp3,
jpg, jpeg, png, heic, gif
```

كما يقبل المستندات التي يستطيع النظام التعرف عليها. التنزيل يجب أن يدعم:

- العمل في الخلفية قدر الإمكان.
- إظهار نسبة التقدم.
- التحقق من HTTP status بين 200 و299.
- رفض الاستجابة إذا كان `Content-Type` من نوع `text/html`.
- تحديد الامتداد بالترتيب التالي: الامتداد المفضل، ثم امتداد URL، ثم اسم الملف المقترح، ثم MIME type، وأخيرًا `dat`.
- حفظ الملف أولًا في مجلد مؤقت، ثم نقله إلى مكتبة التطبيق.

## 4.4 Thumbnail URLs

إذا أعاد resolver قيمة `thumbnail`، يتم تحميلها كصورة شبكة عادية:

```http
GET {thumbnailUrl}
```

فشل الصورة لا يفشل عملية التنزيل؛ تظهر أيقونة افتراضية بدلًا منها.

## 4.5 Google AdMob وUMP

التطبيق يستخدم:

- Google Mobile Ads.
- User Messaging Platform لجمع موافقة الخصوصية عند الحاجة.
- App Tracking Transparency على iOS.
- Banner ads.
- Native ads.
- Interstitial ads.

الإعلانات لا تبدأ إلا إذا كانت قيمة `enableAds` في Firestore تساوي true. عند عدم السماح بالتتبع، تُرسل الإعلانات كإعلانات غير مخصصة باستخدام `npa=1`.

أماكن العرض:

- Banner في Settings.
- Native card داخل تجربة الاستيراد/التنزيل.
- Interstitial قبل أو بعد بعض العمليات المكتملة حسب حالة الإعلان الجاهز.

في Flutter تستخدم حزمة Google الرسمية الخاصة بإعلانات الموبايل، مع تنفيذ UMP وATT لكل منصة. يجب فصل IDs الخاصة بالـ Debug عن Production.

## 4.6 صفحات ويب ثابتة

ليست APIs، لكنها اتصالات خارجية مطلوبة:

```text
https://3reeb.com/privacy.html
https://3reeb.com/terms.html
https://support.google.com/admob/answer/2753860
```

تُفتح داخل متصفح مدمج أو Custom Tab/Safari View.

---

## 5. منطق شاشة Download

### 5.1 استخراج الرابط

المستخدم قد يلصق رابطًا وحده أو نصًا يحتوي على رابط. المطلوب:

1. تقسيم النص حسب المسافات والأسطر.
2. البحث عن أول token يحتوي `http://` أو `https://`.
3. إزالة علامات الترقيم المحيطة بالرابط.
4. إذا لم توجد scheme وكان أول token يحتوي نقطة، إضافة `https://`.
5. رفض القيمة إذا لم تنتج URL من نوع HTTP/HTTPS.

### 5.2 القرار بين direct download وresolver

```text
URL صالح
  |
  +-- امتداد مباشر؟ --> تنزيل فوري
  |
  +-- ليس مباشرًا
          |
          +-- resolver غير مهيأ --> رسالة Not a file link
          |
          +-- resolver مهيأ --> POST /v1/social/autolink
                                  |
                                  +-- عرض خيارات الجودة
                                  +-- اختيار خيار
                                  +-- تنزيل URL الناتج
```

### 5.3 بعد التنزيل

- إضافة الملف إلى مكتبة التطبيق.
- احترام إعداد Auto-save:
  - Photos.
  - Files.
  - Off.
- عرض حالة النجاح أو الخطأ.

---

## 6. المكتبة المحلية

المشروع لا يستخدم قاعدة بيانات للوسائط. **مجلد الملفات نفسه هو مصدر الحقيقة**.

البنية المنطقية:

```text
Application Support/
  Library/
    Media/          # الملفات الدائمة
    Thumbnails/     # thumbnails cache
    favorites.json  # أسماء الملفات المفضلة

Temporary/
  VeloWork/         # ملفات العمل والتصدير المؤقتة
```

يتم تنظيف `VeloWork` عند تشغيل التطبيق. تنظيف الـ cache يحذف Thumbnails وWork فقط، ولا يحذف Media.

نموذج الملف:

```dart
enum MediaKind { video, image, audio, gif, document }

class MediaItem {
  final String filePath;
  final DateTime createdAt;
  final int byteSize;

  String get fileName;
  String get title;
  MediaKind get kind;
}
```

أنواع المستندات المدعومة تشمل:

```text
PDF, TXT, RTF, presentations, spreadsheets, ZIP, EPUB,
DOC, DOCX, Pages, Keynote, Numbers, XLS, XLSX, PPT, PPTX
```

وظائف المكتبة:

- عرض Grid للملفات.
- بحث بالاسم.
- فلاتر: All, Videos, Photos, Audio, Documents, Favorites.
- Preview مناسب لنوع الملف.
- إضافة للمفضلة وإزالتها.
- Rename مع تنظيف `/`, `\`, `:` والنقاط في بداية الاسم.
- منع تكرار الأسماء بإضافة `(1)`, `(2)` وهكذا.
- حذف ملف واحد أو عدة ملفات.
- حفظ نسخة إلى Photos أو Files.
- Import من مكتبة التطبيق أو Photos أو Files.
- حساب مدة الفيديو والصوت مع cache في الذاكرة.

---

## 7. محرر الفيديو

## 7.1 نموذج المشروع

```dart
class EditClip {
  String id;
  String fileName;
  double sourceDuration;
  double trimStart;
  double trimEnd;
  double speed;          // 0.25 إلى 4
  double volume;         // 0 إلى 2
  int quarterTurns;      // 0 إلى 3
  bool flipHorizontal;
  bool flipVertical;

  double get trimmedDuration => max(0, trimEnd - trimStart);
  double get outputDuration => trimmedDuration / max(speed, 0.1);
}

class AudioSettings {
  String? musicFileName;
  double musicVolume;    // default 0.7
  double originalVolume; // default 1
  bool muteOriginal;
  double fadeIn;
  double fadeOut;
}

class EditDocument {
  List<EditClip> clips;
  CanvasAspect canvas;
  FilterPreset filter;
  AudioSettings audio;
}
```

مدة الناتج هي مجموع `outputDuration` لجميع المقاطع، والمقاطع تعمل بالتتابع.

## 7.2 وظائف الـ Timeline

- إضافة عدة مقاطع فيديو.
- تحديد مقطع.
- Trim للبداية والنهاية.
- استبدال المقطع مع الاحتفاظ بإعدادات السرعة والصوت والدوران والانعكاس.
- حذف المقطع.
- تدوير 90 درجة في كل ضغطة.
- Flip أفقي ورأسي.
- تغيير صوت المقطع من 0% إلى 200%.
- تغيير السرعة من 0.25x إلى 4x.
- إعادة ترتيب المقاطع.
- Preview للمشروع كاملًا.
- Undo وRedo باستخدام snapshots، بحد أقصى 50 تعديلًا.

## 7.3 أبعاد Canvas

```text
Original
9:16
16:9
1:1
4:5
4:3
```

دقة التصدير الافتراضية 1080p، والخيارات:

```text
720p
1080p
4K / 2160p
```

القيمة تمثل أقصر ضلع، ويتم حساب الضلع الآخر حسب aspect ratio، مع جعل الأبعاد أرقامًا زوجية لتوافق codecs.

## 7.4 الفلاتر

```text
None
Warm
Cool
Vivid
Mono
Noir
Fade
Cinematic
Vintage
Dream
```

المعالجة الحالية تستخدم Core Image. تطبيق Flutter يحتاج تنفيذًا مطابقًا باستخدام shaders أو مكتبة معالجة صور/فيديو، أو طبقة Native لكل منصة.

## 7.5 الصوت والموسيقى

- Mute للصوت الأصلي.
- التحكم في مستوى الصوت الأصلي.
- إضافة ملف موسيقى من مكتبة التطبيق أو Files.
- إزالة الموسيقى.
- Music volume.
- Fade in وFade out.
- إذا كانت الموسيقى أقصر من الفيديو، تتكرر حتى نهاية المشروع.

## 7.6 التصدير

Pipeline التصدير المطلوب:

```text
Load clips
 -> apply trim
 -> concatenate
 -> apply speed/time scale
 -> rotate/flip
 -> fit into canvas
 -> render blurred background for aspect mismatch
 -> apply global filter
 -> mix original audio and music
 -> apply fades
 -> encode output
 -> add to local library
```

الخلفية عند اختلاف أبعاد المقطع عن Canvas عبارة عن نسخة مكبرة ومموهة من نفس الفيديو، بينما يظهر الفيديو الأصلي في المنتصف بنمط fit.

---

## 8. الأدوات السريعة

## 8.1 Compress

الخيارات:

- Small: حد أقصى للضلع الطويل 1280.
- Balanced: حد أقصى 1920.
- High: حد أقصى 3840.
- Target size اختياري من 5 إلى 500 MB.
- Codec مستخدم افتراضيًا: HEVC.
- Output: MP4.

عند تحديد حجم مستهدف، يحسب bitrate تقريبيًا:

```text
totalBits = targetBytes * 8 * 0.95
videoBitrate = totalBits / duration - audioBitrate
minimum video bitrate = 150,000 bps
```

## 8.2 Convert

Codecs:

```text
H.264
HEVC
```

Containers:

```text
MP4
MOV
M4V
```

## 8.3 Extract Audio

```text
M4A
WAV
```

## 8.4 GIF

- تحويل الفيديو إلى GIF.
- FPS من 5 إلى 20.
- القيمة الافتراضية 12 FPS.

## 8.5 Extract Frames

- استخراج من 1 إلى 30 frame موزعة على مدة الفيديو.
- الافتراضي 6 frames.
- الناتج JPEG files منفصلة تضاف إلى المكتبة.

كل أداة تعرض progress، تحفظ النتائج في مكتبة التطبيق، ثم قد تطلب عرض Interstitial ad بعد اكتمال العملية.

---

## 9. Image Lab

الوظائف:

- اختيار صورة.
- تحميل نسخة مناسبة للمعالجة بحد أقصى 2048 pixel للمعاينة.
- تطبيق نفس فلاتر محرر الفيديو.
- Crop حسب Canvas Aspect.
- اختيار الصيغة:
  - HEIC.
  - JPEG.
  - PNG.
- جودة JPEG/HEIC الحالية 0.9.
- حفظ النتيجة داخل مكتبة التطبيق.

---

## 10. Studio Assistant

المساعد **Offline بالكامل** ولا يستخدم OpenAI أو أي LLM API.

طريقة العمل:

- اكتشاف اللغة: العربية أو الإنجليزية.
- تحليل keywords وregular expressions.
- مطابقة الموضوع مع Phrasebook ثابت.
- قراءة إحصائيات المكتبة: عدد الفيديوهات والصور والصوت وآخر أسماء الملفات.
- تقديم شرح لاستخدام التطبيق.
- تقديم أفكار محتوى.
- تحليل طلبات إعداد الفيديو مثل mood، filter، speed، aspect ومدة الفيديو.
- إنشاء Caption وhashtags واسم مقترح للتصدير.
- الاحتفاظ بسياق بسيط لطلبات مثل "المزيد".
- محاكاة الكتابة التدريجية في الواجهة.
- Safety filter بسيط قائم على قائمة كلمات محظورة.

لو المطلوب تطابق كامل، انقل القواعد والـ phrasebook إلى Dart كما هي. لا تستبدله تلقائيًا بخدمة AI خارجية لأن ذلك سيغير الخصوصية والتكلفة والسلوك.

نماذج البيانات:

```dart
class LibraryStats {
  int videoCount;
  int imageCount;
  int audioCount;
  List<String> recentNames;
}

class CaptionDraft {
  String caption;
  List<String> hashtags;
  String exportName;
}
```

---

## 11. الإعدادات

القيم التي تحفظ محليًا:

```text
termsAccepted
hapticsEnabled       default: true
defaultResolution    default: 1080p
appearance           default: system
autoSave             default: off
```

الشاشة تعرض أيضًا:

- تغيير لغة التطبيق من إعدادات النظام.
- Light / Dark / System.
- Photos/Files permissions.
- مساحة مكتبة التطبيق.
- مساحة الـ cache.
- المساحة الحرة على الجهاز.
- Clear caches.
- Privacy Policy وTerms.
- Rate app وShare app.
- Replay onboarding.
- Report inappropriate ad عند تفعيل الإعلانات.

في Flutter يمكن حفظ القيم البسيطة باستخدام Shared Preferences أو بديل محلي مماثل.

---

## 12. الصلاحيات ومتطلبات المنصات

### iOS

- قراءة Photos لاختيار الفيديوهات والصور.
- إضافة ملفات إلى Photos.
- App Tracking Transparency للإعلانات المخصصة.
- Background URLSession أو بديل Native للتنزيلات الخلفية الحقيقية.
- File picker وDocument export.

### Android

- Photo Picker في الإصدارات الحديثة.
- صلاحيات الصور والفيديو حسب إصدار Android.
- Notifications إذا كانت مكتبة background download تحتاج foreground notification.
- WorkManager/foreground service للتنزيل أو التصدير الطويل.
- MediaStore لحفظ الملفات في Gallery.

يجب تجنب طلب صلاحية تخزين عامة إذا كان Photo Picker وStorage Access Framework يحققان المطلوب.

---

## 13. Architecture مقترحة لمشروع Flutter

```text
lib/
  app/
    app.dart
    router.dart
    dependencies.dart

  core/
    config/
      remote_settings.dart
    network/
      resolver_client.dart
      download_service.dart
    ads/
      ads_coordinator.dart
    storage/
      app_paths.dart
      preferences.dart
    media/
      media_engine.dart
      media_engine_channel.dart
      thumbnail_service.dart
    localization/
    theme/

  features/
    onboarding/
    download/
    create/
    editor/
    quick_tools/
    image_lab/
    library/
    settings/
    studio/

  models/
    media_item.dart
    edit_document.dart
    resolved_media.dart
```

الفصل المقترح:

- **Presentation:** Widgets وstate الخاص بالشاشات.
- **Application/Domain:** use cases مثل ResolveLink وDownloadMedia وExportProject.
- **Data:** Firestore وHTTP وملفات الجهاز والإعدادات.
- **Native Media Layer:** التشفير والتركيب والـ background execution.

يمكن استخدام Riverpod أو BLoC أو أي state management معتمد في المشروع؛ المهم عدم وضع منطق الميديا والشبكة داخل Widgets.

---

## 14. حزم وقدرات Flutter المطلوبة

اختيار الإصدارات يجب أن يتم وقت التنفيذ حسب Flutter SDK والمنصات المستهدفة، لكن الفئات المطلوبة هي:

- Firebase Core وCloud Firestore.
- Google Mobile Ads.
- HTTP client يدعم progress وtimeouts وheaders.
- Path provider للوصول إلى Application Support وTemporary directories.
- Shared Preferences للإعدادات البسيطة.
- File picker وPhoto picker/import.
- Save to gallery/Photos وDocument export.
- Video player للمعاينة.
- Thumbnail generation.
- Background downloader.
- Localization للعربية والإنجليزية وRTL.
- Native platform channels لمحرك الميديا إذا لم توجد مكتبة موثوقة تحقق كل المتطلبات.

### قرار مهم: محرك الميديا

المساواة مع تطبيق iOS الحالي صعبة باستخدام Widgets وحزم Dart فقط. الخيارات:

1. **Native bridge موصى به لأعلى جودة:**
   - iOS: AVFoundation/Core Image.
   - Android: Media3 Transformer وMediaCodec/OpenGL، مع تنفيذ إضافي للميزات غير المتاحة.
2. **محرك FFmpeg مدمج:** أسرع في الوصول لتوافق وظيفي، لكن يجب مراجعة صيانة الحزمة، حجم التطبيق، ترخيص FFmpeg/codecs، ودعم background execution قبل اعتماده.

لا يُنصح ببدء شاشة المحرر قبل عمل Proof of Concept يثبت: concatenate + trim + speed + filter + audio mix + 4K export على iOS وAndroid.

---

## 15. الأمان والخصوصية

### مشكلة RapidAPI key

المشروع الحالي يحمّل `rapidApiKey` من Firestore إلى تطبيق الموبايل. هذا لا يجعله سرًا؛ يمكن استخراج المفتاح من التطبيق أو مراقبة الطلب.

التصميم الأفضل:

```text
Flutter App
   |
   | POST /resolve-social-link
   v
Your Backend / Cloud Function
   |
   | RapidAPI key محفوظ على الخادم
   v
RapidAPI
```

بهذا يمكن إضافة authentication وrate limiting ومنع استهلاك المفتاح خارج التطبيق.

### Firebase

- Firebase API key الموجود في ملفات التطبيق ليس سرًا بحد ذاته.
- الحماية تعتمد على Firestore Security Rules.
- الأفضل جعل مستند الإعدادات read-only للعملاء ومنع الكتابة تمامًا.
- لا تُخزن أسرار حقيقية داخل مستند يستطيع تطبيق العميل قراءته.

### تنزيل الروابط

- السماح فقط بـ HTTP/HTTPS.
- وضع حد أقصى لحجم الملف.
- استخدام timeout وإتاحة الإلغاء.
- التحقق من Content-Type وعدم الاعتماد على الامتداد فقط.
- تنظيف أسماء الملفات.
- عدم تنفيذ أو فتح ملفات مجهولة تلقائيًا.

### الخصوصية

- توضيح أن رابط السوشيال يُرسل إلى مزود خارجي.
- عدم إرسال ملفات المكتبة أو نص Studio إلى الخادم.
- عدم تسجيل RapidAPI key أو الروابط الخاصة في logs.

---

## 16. تحسينات مطلوبة أثناء النقل

التنفيذ الحالي يعمل، لكن يفضل أن يعالج مشروع Flutter النقاط التالية:

1. فحص HTTP status لاستجابة resolver قبل JSON parsing.
2. تعريف أخطاء منفصلة: timeout، no internet، invalid response، rate limit، unauthorized، unsupported media.
3. دعم cancel وretry للتنزيل والتصدير.
4. حفظ حالة التنزيلات الخلفية بعد إغلاق التطبيق.
5. وضع حد لحجم cache وحجم الملفات المستوردة.
6. نقل RapidAPI key إلى Backend.
7. إضافة tests لعقود JSON وحسابات bitrate ومدة timeline.
8. تسجيل أخطاء تقني لا يحتوي على بيانات أو مفاتيح حساسة.
9. التعامل مع نقص المساحة قبل بدء export كبير.
10. اختبار HEVC وHEIC على أجهزة لا تدعمهما بالكامل، وتوفير fallback.

---

## 17. خطة تنفيذ مقترحة

### المرحلة 1: الأساس

- إنشاء Flutter project.
- Theme وLocalization وNavigation.
- Onboarding وSettings المحلية.
- App paths ومكتبة الملفات.
- Import/Export من Photos وFiles.

### المرحلة 2: الشبكة

- Firebase initialization.
- Remote settings.
- Resolver API.
- Direct/background download.
- Download options وprogress والأخطاء.

### المرحلة 3: الأدوات السريعة

- Proof of Concept لمحرك الميديا.
- Compress وConvert.
- Extract Audio.
- GIF وFrames.
- إضافة النتائج للمكتبة.

### المرحلة 4: المحرر

- EditDocument وtimeline state.
- Preview.
- Trim وreorder وreplace وdelete.
- Speed وrotate وflip.
- Canvas وfilters.
- Audio mixing.
- Undo/Redo.
- Export بجودات 720p/1080p/4K.

### المرحلة 5: الخدمات الإضافية

- Image Lab.
- Studio Assistant المحلي.
- AdMob وconsent.
- Storage summary وcache management.

### المرحلة 6: الجودة والإطلاق

- Unit tests وintegration tests.
- اختبار أجهزة ضعيفة وفيديوهات طويلة.
- فشل الشبكة واستكمال التنزيل.
- اختبار المساحة والصلاحيات.
- مراجعة privacy وFirebase rules وAdMob IDs.

---

## 18. معايير القبول

يعتبر نقل المشروع ناجحًا عندما:

- يعمل التطبيق بالعربية والإنجليزية مع RTL صحيح.
- لا تظهر الشاشة الرئيسية قبل انتهاء startup/onboarding logic.
- يمكن تنزيل direct URL وعرض progress وحفظ الناتج.
- يمكن حل social URL عند تفعيل Firestore config.
- تبقى الميديا محلية ولا تُرفع لخادم التطبيق.
- المكتبة تدعم البحث والفلاتر والمفضلة وإعادة التسمية والحذف والتصدير.
- تعمل الأدوات الخمس وتعطي نتائج قابلة للفتح.
- يدعم المحرر جميع خصائص `EditDocument` الحالية.
- Preview قريب من نتيجة export النهائية.
- Undo/Redo يحتفظ بآخر 50 تعديلًا.
- تعمل دقات 720p و1080p و4K ضمن قدرات الجهاز.
- يعمل Image Lab بالفلاتر والأبعاد والصيغ الثلاث.
- يعمل Studio بدون إنترنت.
- لا تظهر الإعلانات إذا كان `enableAds=false`.
- فشل Firebase أو الشبكة لا يمنع فتح التطبيق.
- تنظيف cache لا يحذف مكتبة المستخدم.

---

## 19. مراجع التنفيذ داخل مشروع Swift الحالي

- تشغيل التطبيق والاعتماديات: `Velo/App/AppDependencies.swift`
- التبويبات: `Velo/App/RootView.swift`
- الإعدادات المحلية: `Velo/App/UserSettings.swift`
- Firestore config: `Velo/Core/Config/RemoteSettings.swift`
- RapidAPI والتنزيل: `Velo/Features/Download/DownloadCenter.swift`
- منطق شاشة التنزيل: `Velo/Features/Download/DownloadView.swift`
- نماذج المكتبة: `Velo/Core/Library/MediaModels.swift`
- إدارة الملفات: `Velo/Features/Library/MediaLibrary.swift`
- Import/Export: `Velo/Core/Library/MediaTransfer.swift`
- نماذج المحرر: `Velo/Core/MediaEngine/EditDocument.swift`
- خيارات ودقات الميديا: `Velo/Core/MediaEngine/MediaOptions.swift`
- محرك الميديا: `Velo/Core/MediaEngine/MediaEngine.swift`
- تركيب المشروع: `Velo/Core/MediaEngine/Composition/CompositionBuilder.swift`
- الفلاتر: `Velo/Core/MediaEngine/FilterPreset.swift`
- أدوات الفيديو: `Velo/Features/QuickTools/ToolRunView.swift`
- Image Lab: `Velo/Features/ImageLab/ImageLabView.swift`
- Studio المحلي: `Velo/Core/AI/LocalAssistant.swift`
- الإعلانات: `Velo/Core/Ads/Ads.swift`

---

## 20. الخلاصة الفنية

نقل الواجهات والإعدادات وFirestore والتنزيل والمكتبة إلى Flutter مباشر نسبيًا. الجزء عالي المخاطر هو **محرك الفيديو**: المعاينة، الـ timeline، الفلاتر، تركيب الصوت، والـ export المتطابق عبر iOS وAndroid.

أفضل بداية عملية هي تنفيذ مكتبة الملفات وDownload flow أولًا، بالتوازي مع Proof of Concept صغير لمحرك الميديا. بعد إثبات نجاح التصدير على النظامين، يتم بناء واجهة المحرر فوقه. بهذه الطريقة لا يتم استثمار وقت كبير في UI قبل التأكد أن أساس المعالجة قابل للتنفيذ بالجودة المطلوبة.
