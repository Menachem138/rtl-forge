<div dir="rtl" align="right">

# Claude Desktop Official RTL

פתרון RTL לעברית, ערבית ופרסית בתוך **אפליקציית Claude Desktop הרשמית במק**.

הגישה הזו לא יוצרת `Claude-RTL.app`, לא מעתיקה את Claude, לא משנה את `/Applications/Claude.app`, ולא חותמת אותו מחדש.

זה חשוב כי במק יש הבדל בין "אפליקציה שנראית כמו Claude" לבין האפליקציה הרשמית שחתומה על ידי Anthropic. מנוי, היסטוריה, Cowork ו-Claude Code יכולים להיות תלויים בזהות הרשמית, בהרשאות, ב-Keychain וב-Team ID.

## התקנה קצרה

```bash
git clone https://github.com/YOUR_USERNAME/claude-desktop-official-rtl.git
cd claude-desktop-official-rtl
npm install
npm run build
official-runtime/macos/launch-rtl-forge.sh
official-runtime/macos/install-watchdog.sh
```

אם macOS לא מאפשר לסקריפט ללחוץ על תפריט Developer של Claude, צריך לאשר פעם אחת:

```text
System Settings -> Privacy & Security -> Accessibility
```

לאשר את מי שמריץ:

- `Terminal` בהרצה ידנית.
- `bash` עבור ה-watchdog האוטומטי.
- אפליקציית IDE/agent אם מריצים משם.

## איך זה עובד

1. מאמתים ש-`/Applications/Claude.app` עדיין חתום על ידי Anthropic Team ID `Q6L2SF6YDW`.
2. מפעילים את תפריט ה-Developer המובנה של Claude.
3. משתמשים בפריט הרשמי `Developer -> Enable Main Process Debugger`.
4. מתחברים מקומית ל-`127.0.0.1:9229`.
5. מזריקים את מנוע ה-RTL לתוך חלונות/frames של `claude.ai` ו-`claude.com`.
6. סוגרים את ה-inspector אחרי ההזרקה.

אין שליחה של תוכן שיחות החוצה, ואין שינוי בקבצי Claude.

## למה Chrome לפעמים נפתח

כשפותחים את ה-main process debugger של Electron, Chrome לפעמים מזהה את ה-Node inspector ופותח `chrome://inspect`.

זה לא תוסף Chrome, לא טלמטריה, ולא שרת מרוחק. זה endpoint מקומי זמני על `127.0.0.1`, והסקריפט סוגר אותו אחרי ההזרקה. ברירת המחדל החדשה היא בדיקת רענון פעם ב-24 שעות.

בדיקה שאין inspector פתוח:

```bash
lsof -nP -iTCP:9229 -sTCP:LISTEN
```

אם אין פלט, הפורט סגור.

## Claude Code

Claude Code משתמש ב-xterm.js עבור הטרמינל. טרמינל חייב להישאר LTR, אחרת פקודות shell, נתיבים, prompt וקוד יכולים להשתבש.

לכן הפתרון לא נוגע ב-xterm:

- לא מוסיף `dir="auto"` ל-textarea הנסתר של xterm.
- לא מזריק spans לתוך פלט הטרמינל.
- לא שם חותמות direction על DOM של הטרמינל.

הטקסט מסביב עדיין יכול להיות RTL. הטרמינל עצמו נשאר תקין.

## אפליקציות נוספות

נכון לעכשיו הנתיב הנתמך בפועל הוא Claude Desktop הרשמי במק.

Hermes Desktop נראה כמועמד טוב, אבל הנתיב הנכון שם הוא תיקון בקוד המקור של Hermes עצמו: האפליקציה היא Electron, יש לה build מקומי, וכבר קיימים בה חלקים של bidi/RTL. לכן עדיף PR נקי ל-Hermes מאשר הזרקה חיצונית.

Codex Desktop כרגע הוא מחקר בלבד. האפליקציה הרשמית חתומה על ידי OpenAI, עם Hardened Runtime, ואין בה את אותו פריט `Developer -> Enable Main Process Debugger` שבו Claude משתמש. לא נכון להעתיק, לפרק, לתקן או לחתום מחדש את Codex כי זה עלול לשבור זהות אפליקציה, הרשאות וחשבון.

מצב "החל על כל האפליקציות" לא צריך להיות ברירת מחדל. אם נוסיף אותו בעתיד, הוא צריך להיות ניסיוני, כבוי מראש, עם allowlist לפי אפליקציה, דילוג על טרמינלים/עורכי קוד, וכפתור כיבוי ברור.

ראו: [docs/APP_ADAPTERS.md](APP_ADAPTERS.md)

## מה שלנו (חשוב)

| שכבה | מה זה | מקור |
|---|---|---|
| **Official runtime** | הזרקה ל־Claude הרשמי בלי copy/patch/re-sign, watchdog, ensure | **עבודה מקורית** |
| **Manager** | לוח בקרה בסרגל, סטטוס, verify | **עבודה מקורית** |
| **Payload v2** | מנוע layout-only — CSS + dir, בלי לשכתב טקסט | **עבודה מקורית** (`payload-v2/`) |

`npm run build` בונה **רק** מ־`payload-v2`. תיקיות `engine/` / `dom/` ישנות (אם נשארו) לא נכנסות ל־payload של המוצר.

מיפוי: [OWNERSHIP.md](OWNERSHIP.md) · [NOTICE](../NOTICE) · [CONTRACT](../payload-v2/CONTRACT.md)

</div>
