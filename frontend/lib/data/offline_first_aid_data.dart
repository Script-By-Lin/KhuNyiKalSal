class FirstAidGuideItem {
  final String id;
  final String titleMm;
  final String titleEn;
  final String category;
  final String icon;
  final List<String> stepsMm;
  final List<String> stepsEn;
  final List<String> cautionsMm;
  final List<String> cautionsEn;

  const FirstAidGuideItem({
    required this.id,
    required this.titleMm,
    required this.titleEn,
    required this.category,
    required this.icon,
    required this.stepsMm,
    required this.stepsEn,
    required this.cautionsMm,
    required this.cautionsEn,
  });
}

class OfflineFirstAidData {
  static const List<FirstAidGuideItem> guides = [
    FirstAidGuideItem(
      id: 'cpr',
      titleMm: 'ရင်ဘတ်ဖိနှိပ် ရှေးဦးပြုစုနည်း (CPR)',
      titleEn: 'Cardiopulmonary Resuscitation (CPR)',
      category: 'Medical',
      icon: 'favorite',
      stepsMm: [
        '၁။ လူနာ သတိရှိမရှိ၊ အသက်ရှူမရှူ စစ်ဆေးပါ။ မေးခိုင်ပြီး အသံပြု၍ ခေါ်ပါ။',
        '၂။ ၁၉၁ (လူနာတင်ယာဉ်) သို့ ချက်ချင်း ဖုန်းခေါ်ဆို၍ အရေးပေါ်အကူအညီ တောင်းပါ။',
        '၃။ လူနာအား ညီညာမာကျောသော ကြမ်းပြင်ပေါ်တွင် ပက်လက်အနေအထား ထားပါ။',
        '၄။ လက်နှစ်ဖက်ကို ရင်ညွန့်အလယ်တည့်တည့်တွင် ထပ်တင်ပြီး လက်မောင်းကို ဖြောင့်တန်းစွာ ထားပါ။',
        '၅။ တစ်မိနစ်လျှင် အကြိမ် ၁၀၀ မှ ၁၂၀ နှုန်းဖြင့် ရင်ဘတ်ကို ၂ လက်မခန့် နစ်အောင် အားပြင်းပြင်းနှင့် မြန်မြန် ဖိနှိပ်ပါ။',
        '၆။ ကယ်ဆယ်ရေးအဖွဲ့ ရောက်ရှိလာချိန်အထိ သို့မဟုတ် လူနာ သတိပြန်လည်လာချိန်အထိ မရပ်မနား ဆက်လက်လုပ်ဆောင်ပါ။',
      ],
      stepsEn: [
        '1. Check for responsiveness and breathing. Tap the shoulders and shout.',
        '2. Call 191 (Ambulance) immediately for emergency dispatch.',
        '3. Place the person on their back on a firm, flat surface.',
        '4. Place hands interlaced in the center of the chest with straight arms.',
        '5. Push hard and fast: 100 to 120 compressions per minute, at least 2 inches deep.',
        '6. Continue uninterrupted until professional medical help arrives or the person recovers.',
      ],
      cautionsMm: [
        '⚠️ ရင်ဘတ်ဖိနှိပ်နေစဉ် လက်ကို ရင်ဘတ်ပေါ်မှ လုံးဝ မကြွပါစေနှင့်။',
        '⚠️ လူနာ သတိရှိနေပါက CPR လုံးဝ မလုပ်ပါနှင့်။',
      ],
      cautionsEn: [
        '⚠️ Allow chest to fully recoil between each compression.',
        '⚠️ Do NOT perform CPR if the victim is conscious and breathing normally.',
      ],
    ),
    FirstAidGuideItem(
      id: 'bleeding',
      titleMm: 'သွေးထွက်လွန်ခြင်း ရှေးဦးပြုစုနည်း',
      titleEn: 'Severe Bleeding & Wound Control',
      category: 'Medical',
      icon: 'water_drop',
      stepsMm: [
        '၁။ သန့်ရှင်းသောအဝတ် သို့မဟုတ် ပတ်တီးဖြင့် ဒဏ်ရာပေါ် တိုက်ရိုက် အားပြင်းပြင်း ဖိထားပါ။',
        '၂။ ဒဏ်ရာရရှိသော နေရာကို နှလုံးထက် မြင့်သော အနေအထားသို့ မြှောက်ထားပါ။',
        '၃။ ပတ်တီးကို တင်းကျပ်စွာ စည်းနှောင်ပါ။ သွေးစိမ့်ထွက်ပါက မူလပတ်တီးကို မဖြုတ်ဘဲ အပေါ်မှ ထပ်စည်းပါ။',
        '၄။ သွေးထွက် မရပ်မချင်း ဆက်လက်ဖိထားပြီး ဆေးရုံသို့ အမြန်ဆုံး ပို့ဆောင်ပါ။',
      ],
      stepsEn: [
        '1. Apply direct, firm pressure on the wound with a clean cloth or sterile gauze.',
        '2. Elevate the injured limb above the heart level if possible.',
        '3. Wrap a bandage firmly over the dressing. If blood soaks through, add another layer without removing the first.',
        '4. Keep pressure applied continuously until emergency assistance arrives.',
      ],
      cautionsMm: [
        '⚠️ ဒဏ်ရာထဲ စူးဝင်နေသော အရာဝတ္ထု (မှန်၊ သံချောင်း) များရှိပါက ဆွဲမနုတ်ပါနှင့်။',
        '⚠️ သွေးကြောပိတ်စည်းခြင်း (Tourniquet) ကို အသက်အန္တရာယ်ရှိမှသာ သုံးပါ။',
      ],
      cautionsEn: [
        '⚠️ Do NOT remove embedded objects (glass, metal rods) from the wound.',
        '⚠️ Use a tourniquet only as a last resort for life-threatening limb hemorrhages.',
      ],
    ),
    FirstAidGuideItem(
      id: 'burns',
      titleMm: 'မီးလောင်ဒဏ်ရာနှင့် အပူလောင်ခြင်း',
      titleEn: 'Burns & Scalds Treatment',
      category: 'Fire',
      icon: 'local_fire_department',
      stepsMm: [
        '၁။ လောင်ကျွမ်းနေသော အပူရင်းမြစ်မှ ချက်ချင်း ဖယ်ခွာပါ။',
        '၂။ မီးလောင်ဒဏ်ရာကို ရိုးရိုးရေအေး (ရေခဲရေ မဟုတ်) ဖြင့် အနည်းဆုံး ၁၅ မိနစ်မှ မိနစ် ၂၀ ခန့် ဆက်တိုက် လောင်းပေးပါ။',
        '၃။ ဒဏ်ရာနေရာရှိ လက်ဝတ်ရတနာ၊ တင်းကျပ်သောအဝတ်အစားများကို ဖယ်ရှားပါ။',
        '၄။ သန့်ရှင်းသော ပိုးသတ်ပိတ်စ သို့မဟုတ် ပလတ်စတစ်အကြည်စဖြင့် ချောင်ချောင် ဖုံးအုပ်ထားပါ။',
      ],
      stepsEn: [
        '1. Remove the victim from the heat source immediately.',
        '2. Cool the burn under running cool tap water (not ice) for 15-20 minutes.',
        '3. Gently remove tight clothing, rings, or jewelry before swelling occurs.',
        '4. Cover the burn loosely with sterile gauze or clean plastic wrap.',
      ],
      cautionsMm: [
        '⚠️ ရေခဲ၊ သွားတိုက်ဆေး၊ ထောပတ် သို့မဟုတ် ဆီ လုံးဝ မလိမ်းပါနှင့်။',
        '⚠️ အရည်ကြည်ဖုများကို မဖောက်ပါနှင့် (ရောဂါပိုးဝင်နိုင်သည်)။',
      ],
      cautionsEn: [
        '⚠️ Never apply ice, toothpaste, butter, or oil to burns.',
        '⚠️ Do NOT pop or puncture burn blisters.',
      ],
    ),
    FirstAidGuideItem(
      id: 'choking',
      titleMm: 'အသက်ရှူလမ်းကြောင်း ပိတ်ဆို့ခြင်း (သီးခြင်း)',
      titleEn: 'Choking & Airway Obstruction',
      category: 'Medical',
      icon: 'air',
      stepsMm: [
        '၁။ လူနာ အသက်ရှူရခက်ခဲနေပါက ကျောကုန်းကို လက်ဖဝါးဖြင့် အားပြင်းပြင်း ၅ ကြိမ် ပုတ်ပါ။',
        '၂။ လူနာ၏ နောက်မှနေ၍ ခါးကို ပွေ့ဖက်ပြီး လက်သီးဆုပ်ကို ချက်အထက်နားတွင် ထားပါ။',
        '၃။ အခြားလက်တစ်ဖက်ဖြင့် ထပ်အုပ်၍ အတွင်းနှင့် အပေါ်ဘက်သို့ အားဖြင့် ၅ ကြိမ် ဆောင့်ဆွဲဖိညှစ်ပါ (Heimlich Maneuver)။',
        '၄။ အဆို့အပိတ် ထွက်မကျမချင်း ကျောပုတ် ၅ ကြိမ်နှင့် ဝမ်းဗိုက်ဆောင့်ဖိ ၅ ကြိမ်ကို အလှည့်ကျ ပြုလုပ်ပါ။',
      ],
      stepsEn: [
        '1. Stand behind the victim and deliver 5 sharp back blows between the shoulder blades.',
        '2. Wrap arms around victim\'s waist and make a fist just above the navel.',
        '3. Grasp fist with other hand and perform quick, upward abdominal thrusts (Heimlich maneuver).',
        '4. Alternate 5 back blows and 5 abdominal thrusts until the airway is clear.',
      ],
      cautionsMm: [
        '⚠️ ကလေးငယ်များအတွက် ဝမ်းဗိုက်ဖိညှစ်ခြင်းအစား ကျောကုန်းကိုသာ သတိထား ပုတ်ပေးပါ။',
      ],
      cautionsEn: [
        '⚠️ For infants, use chest thrusts and back slaps instead of abdominal thrusts.',
      ],
    ),
    FirstAidGuideItem(
      id: 'earthquake',
      titleMm: 'ငလျင်ဘေး အရေးပေါ် အသက်ရှင်နည်း',
      titleEn: 'Earthquake Safety & Survival',
      category: 'Disaster',
      icon: 'landslide',
      stepsMm: [
        '၁။ ဝပ်ပါ (Drop): လက်နှစ်ဖက်နှင့် ဒူးထောက်၍ မြေပြင်ပေါ် ဝပ်ချပါ။',
        '၂။ ကာပါ (Cover): ခိုင်ခံ့သော စားပွဲအောက်သို့ ဝင်၍ ဦးခေါင်းနှင့် လည်ပင်းကို ကာကွယ်ပါ။',
        '၃]. ကိုင်ပါ (Hold On): ငလျင်လှုပ်ခတ်မှု ရပ်တန့်သည်အထိ စားပွဲခြေထောက်ကို မြဲမြံစွာ ဆုပ်ကိုင်ထားပါ။',
        '၄။ တုန်ခါမှု ပြီးဆုံးပါက လှေကားကိုသာ အသုံးပြု၍ ဘေးလွတ်ရာ ကွင်းပြင်သို့ ထွက်ခွာပါ။',
      ],
      stepsEn: [
        '1. DROP down onto your hands and knees.',
        '2. COVER your head and neck under a sturdy table or desk.',
        '3. HOLD ON to your shelter until the shaking stops completely.',
        '4. Evacuate using stairs only (do not use elevators) to an open area.',
      ],
      cautionsMm: [
        '⚠️ ပြတင်းပေါက်၊ မှန်၊ မီးဆိုင်းနှင့် အထပ်မြင့်တိုက်နံရံများအနီး မနေပါနှင့်။',
        '⚠️ ဓာတ်လှေကား လုံးဝ မသုံးပါနှင့်။',
      ],
      cautionsEn: [
        '⚠️ Stay away from windows, mirrors, glass, and exterior walls.',
        '⚠️ Never use elevators during or after an earthquake.',
      ],
    ),
    FirstAidGuideItem(
      id: 'flood',
      titleMm: 'ရေဘေးနှင့် လျှပ်စစ်အန္တရာယ် ကာကွယ်နည်း',
      titleEn: 'Flood & Electrical Hazard Safety',
      category: 'Disaster',
      icon: 'flood',
      stepsMm: [
        '၁။ အဓိက လျှပ်စစ်မိန်းခလုတ် (Main Switch) နှင့် ဂက်စ်အိုးများကို ချက်ချင်း ပိတ်ပါ။',
        '၂။ အရေးကြီးစာရွက်စာတမ်း၊ ဆေးဝါးနှင့် အရေးပေါ်အထုပ်ကို ယူဆောင်၍ အထပ်မြင့်ရာနေရာသို့ ရွှေ့ပြောင်းပါ။',
        '၃။ ရေစီးသန်သော နေရာများကို ဖြတ်သန်းသွားလာခြင်း လုံးဝ မပြုပါနှင့် (ဒူးခေါင်းမြုပ်ရေစီးသည် ကားကို မျောပါစေနိုင်သည်)။',
        '၄။ ကယ်ဆယ်ရေးအဖွဲ့များထံ အရေးပေါ် SOS သို့မဟုတ် ဖုန်းဖြင့် သတင်းပို့ပါ။',
      ],
      stepsEn: [
        '1. Turn off main electrical breaker switches and gas valves immediately.',
        '2. Take vital documents, emergency medical supplies, and move to higher ground.',
        '3. Never walk or drive through moving floodwaters.',
        '4. Alert rescue authorities with your exact coordinates.',
      ],
      cautionsMm: [
        '⚠️ ရေမြုပ်နေသော လျှပ်စစ်ပစ္စည်းများ၊ ဓာတ်တိုင်များနှင့် မီတာပုံးများကို မထိပါနှင့်။',
        '⚠️ ရေကျနေချိန်တွင်လည်း ရောဂါပိုးမွှားနှင့် တွားသွားသတ္တဝါအန္တရာယ် သတိပြုပါ။',
      ],
      cautionsEn: [
        '⚠️ Avoid contact with flooded electrical wiring and utility poles.',
        '⚠️ Beware of snakes and waterborne contaminants in floodwater.',
      ],
    ),
  ];
}
