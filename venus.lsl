// Easily catch the "my script inserted itself into itself" bug.
#ifdef ALREADY_INCLUDED
#error REDUNDANT INCLUDE DETECTED!
#endif
/* M3+ VENUS HEAD AFTERMARKET CONTROLLER. [1147 LINES]
Core Design by: Motoko Henusaki II
Additional work by: LogicShrimp & Xenhat Liamano
LastMod: 2017-04-25 11:46:01 PM
TODO:
- Deduplicate texturing logic to avoid texturing the same face more than once or twice
- Split Texture application and alpha toggling code
- Blank out faces to make sure we properly set all the required faces properly, then disable blanking.
- add a setting to re-enable texturing on reset
- Minimal re-write of texture application to remove as many texture overwrites as possible.
*/
// #define debug_mode
//#define ADAPTIVE_IRISES /*  TRUE to use outer eye layers for adaptive pupils. */
// #define DEBUG
#ifdef DEBUG
#define db(a) llWhisper(DEBUG_CHANNEL,(string)a);
#else
#define db(a) /*noop*/
#endif
#define linear_pupil_response
#define can_blink
#ifdef can_blink
integer is_blinking = FALSE;
#endif
integer responds_to_typing = TRUE; /*  TRUE if head can respond to typing. */
integer eyes_visible = FALSE;
#define blink_mult 2
string lastmessage;
/*  Textures */
#define t_brow                 ""
#define t_eye_iris_l           ""
#define t_eye_iris_r           ""
#define t_eye_pupil            ""
#define t_eyelash              ""
#define t_face_l               ""
#define t_face_noshell_l       ""
#define t_face_noshell_nolid_l ""
#define t_face_noshell_nolid_r ""
#define t_face_noshell_r       ""
#define t_face_r               ""
#define t_blush                ""
/*  Colors */
#define c_eye_l <1,1,1>
#define c_eye_pupil_l <1,1,1>
#define c_eye_pupil_r <1,1,1>
#define c_eye_r <1,1,1>
#define c_eye_sclera <1,1,1>
//#define c_eyebrow <0.61176,0.20000,0.12157>
#define c_eyebrow <0.27231,0.16413,0.14175>
#define c_eyelash <0,0,0>
#define c_skin <1,1,1>
/*  Other Parameters */
#define eye_glow 0.0
#define eye_glow_l 0.0
#define fullbright_eyes 0
#define fullbright_eyes_l 0
#define fullbright_pupil FALSE
#define fullbright_pupil_l FALSE
#define pupil_alpha 1
#define pupil_alpha_l 1
#define pupil_glow 0.0
#define pupil_glow_l 0.0
/*  non-textured colors */
/*  vector c_eye_r = <0.42353,0.56863,0.42745>; */
/*  vector c_eye_pupil_r = <0.141, 0.141, 0.141>; */
/*  Internal settings / caching, do not touch. */
float override_l = -1; /*  L pupil override. -1 = auto; 0 = fully constricted, 100 = fully dilated. */
float override_r = -1; /*  R pupil override. -1 = auto; 0 = fully constricted, 100 = fully dilated. */
integer curr_brow_shape = 0;
integer curr_eye_r_opening = 1; // must be >= 1
integer curr_eye_l_opening = 1; // must be >= 1
integer curr_face_shape = 1; // must be >= 1
integer curr_ears_mode = 0;
integer curr_blush_mode = 0;
integer curr_tears_mode = 0;
integer tongue_out = FALSE;
integer flstatus = FALSE;
integer Derpy = 0;
// #if M3K_HUD_SUPPORT
integer Teeny = 0;
// #endif
integer first_pass = 1;
list prims = [];
list wert = [];
#ifdef ADAPTIVE_IRISES
float pup_sc_r = 0.3;
float pup_sc_l = 0.3;
/* SC() - scales 0-100 to pupil texture UV limits. */
float min = 1.5;
float max = 0.3;
float rio = 75;
#endif
integer backup_shell = 0;
integer is_typing = 0;
integer blink_l = 3;
integer blink_r = 3;
integer need_blinking = TRUE;
integer nt101chanl = -1;
// integer lh = -1;
// integer lh2 = -1;
vector eye_r_pos = <0,0,0>;
vector eye_l_pos = <0,0,0>;
integer pupils_dilated = 0;
/*  timer modularity */
integer TIMER_ELAPSED;
key g_ownerKey_k;
#define NO -1
#define stride 7
/* === Notes about the "eyes" mesh === */
/* Face 0: Pupil Right */
/* Face 1: Teeth */
/* Face 2: Teeth */
/* Face 3: Combined Upper Teeth and sclera (SIGH UTI) */
/* face 4: Iris outer Left */
/* Face 5: Pupil Right */
/* Face 6: Tongue */
/* Face 7: Iris outer Right */
Probe()
{
    prims = ["root",1,01,00,02,NO,NO];
    /* note: face 00 on root mesh = eyebags */
    integer i = llGetNumberOfPrims();
    string s;
    while (i > 1){
        /* prims= [name, linkid, skinR, skinL, lashR, lashL,Corner] */
        s = llGetLinkName(i);
        if(s == "facelight"){
            prims += [s, i,NO,NO,NO,NO,NO];
        }
        if(s == "blink0"){
            prims += [s, i,00,03,02,04,01];
        }
        if(s == "blink1"){
            prims += [s, i,00,03,02,04,01];
        }
        if(s == "blink2"){
            prims += [s, i,00,03,02,04,01];
        }
        if(s == "blink3"){
            prims += [s, i,00,03,02,04,01];
        }
        if(s == "eyes"){
            prims += [s, i,03,04,00,NO,NO]; /*M3K COMPAT* sclera,eye,eye */
            prims += ["teeth", i,01,02,NO,NO,NO]; /*M3K COMPAT* teeth,teeth,sclera */
            prims += ["tongue",i,06,NO,NO,NO,NO]; /* *M3K COMPAT* tongue */
        }
        if(s == "ears"){
            prims += [s, i,02,03,01,00,NO]; /*earHR,earER,earHL,earEL */
        }
        if(s == "brow0"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, broww */
        }
        if(s == "brow1"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, broww */
        }
        if(s == "brow2"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, broww */
        }
        if(s == "e01"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e02"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e03"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, teefs */
        }
        if(s == "e04"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL */
        }
        if(s == "e05"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e06"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e07"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, teefs */
        }
        if(s == "e08"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e09"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e10"){
            prims += [s, i,00,03,02,NO,NO]; /*skinR, skinL, teefs */
        }
        if(s == "e11"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e12"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        if(s == "e13"){
            prims += [s, i,00,02,NO,NO,NO]; /*skinR, skinL */
        }
        i--;
    }
    #ifdef debug_mode
    db(llList2CSV(prims));
    #endif
}
#define FI(a,b) llList2Integer(prims,llListFindList(prims,[a])+(2+b))
// #define LN(a) llList2Integer(prim_names_id,llListFindList(prim_names_id,[a])+1)
#define LN(a) llList2Integer(prims,llListFindList(prims,[a])+1)
SetFaceTexture(string what,vector color,float visible)
{
    db("SetFaceTexture in == '"
        + what + ", "+ (string)color + "," + (string)visible + ","
        + (string)eyes_visible + "'");
    integer lin = LN(what);
    if(lin < 1) return;
    integer face0 = FI(what,0);
    integer face1 = FI(what,1);
    integer face2 = FI(what,2);
    integer face3 = FI(what,3);
    /* Save tremendous amounts of memory by avoiding list copy-and-addition */
    wert += [PRIM_LINK_TARGET,lin,PRIM_COLOR,face0,color,visible,PRIM_COLOR,face1,color,visible];
    if(what != "eyes"){
        if(what == "root")
        {
            wert += [PRIM_TEXTURE,face0 ,t_face_noshell_nolid_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1 ,t_face_noshell_nolid_l,<1,1,1>,<0,0,0>,0];
        }
        else if(llSubStringIndex(what,"ears")==0)
        {
            wert += [PRIM_COLOR,face2,color,visible];
            wert += [PRIM_COLOR,face3,color,visible];
            wert += [PRIM_TEXTURE,face3,t_face_r,<1,1,1>,<0,0,0>,0];
            /* Remove spec */
            /* wert += [PRIM_SPECULAR,face2,NULL_KEY,<1,1,1>,<0,0,0>,0,<1,1,1>,0,0]; */
            /* wert += [PRIM_SPECULAR,face3,NULL_KEY,<1,1,1>,<0,0,0>,0,<1,1,1>,0,0]; */
        }
        /* TODO: Check if we can use the textures with alpha for everything but the blink prims instead. - Xenhat */
        else if(llSubStringIndex(what,"brow")==0)
        {
            wert += [PRIM_COLOR,face2,c_eyebrow,visible,
            /* Actual brows */
            PRIM_TEXTURE, face2, t_brow,
            <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
            /* Remaining shells */
            PRIM_TEXTURE, face0, t_face_r,
            <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0,
            /* left side */
            PRIM_TEXTURE, face1, t_face_l,
            <1.0, 1.0, 0.0>, <0.0, 0.0, 0.0>, 0.0
            ];
        }
        else if(llSubStringIndex(what,"b")==0)
        { /* blink* prims */
            wert += [PRIM_TEXTURE,face0,t_face_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1,t_face_l,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
        }
        else if(llSubStringIndex(what,"e")==0)
        {
            /* Teeth */
            wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
            /* Actual mouth shells */
            wert += [PRIM_TEXTURE,face0,t_face_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1,t_face_l,<1,1,1>,<0,0,0>,0];
        }
        // /* The actual eyelashes "hair" */
        // wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
        // wert += [PRIM_COLOR,face2,color,visible];
    }
}
Blitz()
{
    if(wert!=[])
    {
        llSetLinkPrimitiveParamsFast(2,wert);
        wert=[];
        // llOwnerSay("Blitz");
        #ifdef DEBUG
        llSetText("O:48274(52694)/65536\nC:"+
            (string)llGetUsedMemory()
            +"("+(string)llGetSPMaxMemory()
            +")/"+(string)llGetMemoryLimit()+"\nLast Message:\n"+lastmessage
            ,<1,1,1>, 1.0);
        #endif
    }
}
Light(integer on)
{
    integer lin = LN("facelight");
    if(lin < 1) return;
    llSetLinkPrimitiveParamsFast(lin,[PRIM_POINT_LIGHT,on,<1,1,1>,1.0,10.0,0.75]);
}
SetEarsShape(integer mode)
{
    integer lin = LN("ears");
    if(lin < 1) return;
    integer face1 = FI("ears",0); /* human right */
    integer face2 = FI("ears",1);
    integer face3 = FI("ears",2); /* human left */
    integer face4 = FI("ears",3);
    llSetLinkPrimitiveParamsFast(lin,[
        PRIM_COLOR,face1,c_skin,mode==1,PRIM_COLOR,face3,c_skin,mode==1, /*  hoomin */
        PRIM_COLOR,face2,c_skin,mode==2,PRIM_COLOR,face4,c_skin,mode==2
        ]);
}
SetTearsType(integer mode)
{
    llSetAlpha(!(mode==0),3);
    if(mode == 1)
    { llOffsetTexture(0,.25,3); }
    if(mode == 2)
    { llOffsetTexture(0,.75,3); }
}
SetBlushType(integer mode)
{
    llSetAlpha(!(mode==0),4);
    if(mode == 1)
    { llOffsetTexture(0,.99,4); }
    if(mode == 2)
    { llOffsetTexture(0,.66,4); }
    if(mode == 3)
    { llOffsetTexture(0,.33,4); }
}
SetEyeShape(integer idx,integer right){
// SetEyeDirection();
integer lin;
integer skinFace;
integer lashskin;
float visible;
integer i = 0;
string meshname;
while (i < 4){
    meshname = "blink"+(string)i;
    lin = LN(meshname);
    if(lin != -1){
            // Note: This code will break if the id are different accross meshes
            if(right)
            {
                skinFace = FI(meshname,0);
                lashskin = FI(meshname,2);
            }
            else
            {
                skinFace = FI(meshname,1);
                lashskin = FI(meshname,3);
            }
            // if(visible)
                // db("Applying texture on " + (string)what+"("+(string)lin+"), skin face "+(string)skinFace+" and lash face "+(string)skinFace);
                visible = i==(idx-1);
                if( i < 3)
                {
                    /*  Normal eyelash faces */
                    wert += [PRIM_LINK_TARGET,lin
                    ,PRIM_COLOR,skinFace,c_skin,visible
                    ,PRIM_COLOR,lashskin,c_eyelash,visible
                    ,PRIM_TEXTURE,skinFace,t_face_l,<1,1,1>,<0,0,0>,0
                    ,PRIM_TEXTURE,lashskin,t_eyelash,<1,1,1>,<0,0,0>,0
                    ];
                }
                else
                {
                    /*  "closed" eyelashes don't have a texture */
                    wert += [PRIM_LINK_TARGET,lin
                    ,PRIM_COLOR,skinFace,c_skin,visible
                    ,PRIM_COLOR,lashskin,c_eyelash,visible
                    ,PRIM_TEXTURE,skinFace,t_face_l,<1,1,1>,<0,0,0>,0
                    ,PRIM_TEXTURE,lashskin,TEXTURE_BLANK,<1,1,1>,<0,0,0>,0
                    ];
                }
            }
            i++;
        }
    }
//float SC(float a)
//{
//    float aMax = 100.0;
//    float aMin = 0.0;
//    a = CIROF(a);
//    return (a/((aMax-aMin)/(max-min)))+min;
//}
/*  CIROF() - Linear pupil response. Needed by SC(). */
//float CIROF(float in)
//{
//    if(in < 0) in = 0;
//    if(in > 100) in = 100;
//    float mas = in;
//#ifdef linear_pupil_response
//    float Uran = 100-rio; /*  Upper range. */
//    float Lran = rio; /*  Lower range. */
//    if(in == 50)
//    {
//        mas = rio;
//    }
//    else
//    if(in > 50)
//    {
//        mas = (in - 50);
//        mas = rio + (mas / 50 * Uran);
//    }
//    else
//    if(in < 50)
//    {
//        mas = (in / 50 * Lran);
//    }
//#endif
//    return mas;
//}
SetEyeDirection()
{
    integer lin = LN("eyes");
    if(lin < 1) return;
    integer face1 = FI("eyes",1);
// integer face2 = FI("eyes",2);
float scale = 1;
vector erp = eye_r_pos / 25.0;
vector elp = eye_l_pos / 25.0;
vector erp2;
vector elp2;
if(Derpy)
{
    elp .x = (0-erp .x); /*  Derp (iris)! */
    elp2.x = (0-erp2.x); /*  Derp (pupil)! */
}
#ifdef ADAPTIVE_IRISES
/*  Adjust pupil aperture based on sun z. */
vector snz = CFE(llGetSunDirection());
snz.z = (1.0-((snz.z+1.0)/2.0)) * 100.0;
if(override_r == -1)
{
    pup_sc_r = SC(snz.z+(blink_r*blink_mult));
}
else {
    pup_sc_r = SC(override_r+(blink_r*blink_mult));
}
if(override_l == -1)
{
    pup_sc_l = SC(snz.z+(blink_l*blink_mult));
}
else {
    pup_sc_l = SC(override_l+(blink_l*blink_mult));
}
erp2 = erp * pup_sc_r;
elp2 = elp * pup_sc_l;
#endif
// #if M3K_HUD_SUPPORT
//if(Teeny)
//{
//    scale = 1.5; /*  Small irises! */
//}
// #endif
wert += [PRIM_LINK_TARGET,lin,
PRIM_COLOR,face1,c_eye_r,eyes_visible,PRIM_TEXTURE,face1,t_eye_iris_r,<scale,scale,0>,erp,0,
PRIM_FULLBRIGHT,face1,fullbright_eyes,PRIM_GLOW,face1,(eye_glow*(blink_r<3))*eyes_visible,
// PRIM_ALPHA_MODE, face1, PRIM_ALPHA_MODE_MASK, 1,
PRIM_COLOR,7,c_eye_l,eyes_visible,PRIM_TEXTURE,7,t_eye_iris_l,<scale,scale,0>,elp,0,
PRIM_FULLBRIGHT,7,fullbright_eyes_l,PRIM_GLOW,7,(eye_glow_l*(blink_l<3))*eyes_visible
// ,PRIM_ALPHA_MODE, 7, PRIM_ALPHA_MODE_MASK, 1
];
//#ifdef ADAPTIVE_IRISES
//    if(eyes_visible)
//    {
//        chg += [
//        /*  Pupil layers (R,L). */
//        PRIM_COLOR,face2,c_eye_pupil_r,pupil_alpha,PRIM_TEXTURE,
//        face2,t_eye_pupil,<scale,scale,0>*pup_sc_r,erp2,0,
//        PRIM_FULLBRIGHT,face2,fullbright_pupil,
//        PRIM_GLOW,face2,(pupil_glow *(blink_r<3))*pupil_alpha,
//        //PRIM_ALPHA_MODE, face2,
//        //PRIM_ALPHA_MODE_MASK, 1,
//        PRIM_COLOR,5,c_eye_pupil_l,pupil_alpha_l,PRIM_TEXTURE,
//        5,t_eye_pupil,<scale,scale,0>*pup_sc_l,elp2,0,
//        PRIM_FULLBRIGHT,5,fullbright_pupil_l,
//        PRIM_GLOW,5,(pupil_glow_l*(blink_l<3))*pupil_alpha_l
//        //PRIM_ALPHA_MODE, 5,
//        //PRIM_ALPHA_MODE_MASK, 1
//        ];
//    }
//    else
//    {
//        chg += [
//        /*  Pupil layers (R,L). */
//        PRIM_COLOR,face2,c_eye_pupil_r,0,PRIM_FULLBRIGHT,face2,0,PRIM_GLOW,face2,0,
//        PRIM_COLOR,5,c_eye_pupil_l,0,PRIM_FULLBRIGHT,5,0,PRIM_GLOW,5,0
//        ];
//    }
//#endif
// }
}
//vector CFE(vector fwd)
//{
//    rotation res;
//    fwd = llVecNorm(fwd);
//    vector up = <0.0,1.0,0.0>;
//    vector lf = llVecNorm(up%fwd);
//    fwd = llVecNorm(lf%up);/*  else up = llVecNorm(fwd%lf); */
//    res = llAxes2Rot(fwd,lf,up);
//    if(res.z > 1.0) res.z = 1.0; /*  Just in case! */
//    if(res.z < -1.0) res.z = -1.0; /*  Just in case! */
//    return llVecNorm(<1,0,0>*res); /*  Return adjusted vector. */
//}
SetFaceShape(integer idx)
{
    /*  TODO: Change the face IDs to match the HUD ones and avoid all this duplicated logic. */
    /*  Stock IDs appear to start at 1, Motoko' appear to start at 0. */
    if(idx < 0 ) idx = 0;
    else if(idx > 13) idx = 13;
    integer previous_face = curr_face_shape;
    string id;
    if(idx<10){
        id = "e0"+(string)idx;
    }
    else{
        id = "e"+(string)idx;
    }
    SetFaceTexture(id,c_skin,TRUE);
    /*  Fix up previous face shell. */
    if(idx < 14)
    {// This should be hit every time except when toggling tongue
        if(idx != previous_face){
            if(previous_face<10){
                id = "e0"+(string)(previous_face);
            }
            else{
                id = "e"+(string)(previous_face);
            }
            SetFaceTexture(id,c_skin,FALSE);
        }
        #ifdef debug_messages
        else{
            db("requested duplicated sate:"+(string)idx);
        }
        #endif
    }
    /*  Do teeth. */
    integer teeth_visible = 1;
    integer lin = LN("eyes");
    if(lin < 0) return;
    integer lintong = LN("tongue");
    if(lintong < 0) return;
    integer linteet = LN("teeth");
    if(linteet < 0) return;
    db("Tongue:"+(string)lintong);
    if(11 <= idx) teeth_visible = 0;
    // integer face1 = FI("tongue",0); /*  tongue */
    // integer face2 = FI("teeth",0);
    // integer face3 = FI("teeth",1);
    // IMPORTANT NOTE: the Teeth meshes supports some non-grinning
    // variations on state 3,4,7,and 10.
    // We should preserve that functionality while in typing state.
    integer sclera1 = FI("eyes",0); /*  upper teeth, also eye sclera */
    // integer sclera2 = FI("eyes",1); /*  upper teeth, also eye sclera */
    // integer sclera3 = FI("eyes",2); /*  upper teeth, also eye sclera */
    // if(teeth_visible) tongue_out = FALSE;
    db("Teeth:"+(string)teeth_visible);
    list chg = [
    PRIM_LINK_TARGET,lintong,
    PRIM_COLOR,FI("tongue",0),c_skin,tongue_out,
    PRIM_LINK_TARGET,linteet,
    PRIM_COLOR,FI("teeth",0),c_skin,!teeth_visible, /*  teeth 1 */
    PRIM_COLOR,FI("teeth",1),c_skin,teeth_visible /*  teeth 2 */
    ];
    // if(first_pass)
    {
        //    chg += [PRIM_LINK_TARGET,lintong];
        //    /*  left face */
        //    chg += [PRIM_TEXTURE,face1,t_face_l,<1,1,1>,<0,0,0>,0];
        //    /*  gross hack. FIXME with the proper variable */
        //    chg += [PRIM_TEXTURE,0,t_face_l,<1,1,1>,<0,0,0>,0];
        //    chg += [PRIM_LINK_TARGET,linteet];
        //    chg += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
        //    chg += [PRIM_TEXTURE,face3,t_face_r,<1,1,1>,<0,0,0>,0];
        //    /*  Don't do this. */
        if(eyes_visible)
        {
            chg += [PRIM_TEXTURE,sclera1,t_face_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera1,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        //chg += [PRIM_TEXTURE,sclera2,t_face_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera2,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        //chg += [PRIM_TEXTURE,sclera3,t_face_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera3,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        }
        else {
            chg += [PRIM_TEXTURE,sclera1,t_face_noshell_nolid_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera1,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        //chg += [PRIM_TEXTURE,sclera2,t_face_noshell_nolid_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera1,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        //chg += [PRIM_TEXTURE,sclera3,t_face_noshell_nolid_r,<1,1,1>,<0,0,0>,0,PRIM_COLOR,sclera1,<1,1,1>,eyes_visible]; /*  teeth up + sclera */
        }
    }
    wert+=[PRIM_LINK_TARGET,lin]+chg;
    #ifdef extra_sync
    /* Send updates to other parts using the hud format so that it sync properly: e.g. fangs */
    /*  We send this before changing the mouth shells so that it happens roughly at the same time */
    #ifdef old_sync_code
    if((llGetUnixTime() - TIMER_ELAPSED) >= 5) /*  every 5 sec at least */
    {
        /*  if(!is_typing) */
        /*  todo: remove me after confirmed working */
        integer stock_id = idx + 1;
        /*  States where the teeth are visible */
        if(3 == stock_id
            || 4 == stock_id
            || 5 == stock_id
            || 6 == stock_id
            || 7 == stock_id
            || 10 == stock_id
            || 11 == stock_id
            || 12 == stock_id
            )
        {
            TIMER_ELAPSED = llGetUnixTime();
        }
    // }
    // }
    // }
    #else
    // llWhisper(-34525470,"Exp:" + (string)(stock_id));
    #endif
    }
    #endif
    // Skip state 14 since it's only a tongue toggle
    if(idx<14){
        curr_face_shape = idx;
    }
    db("FACE STATE:"+(string)curr_face_shape);
}

integer random_integer(integer min, integer max)
{
    return min + (integer)(llFrand(max - min + 1));
}
default
{
    changed(integer change)
    {
        if(change & CHANGED_OWNER) llResetScript();
        if(change & CHANGED_INVENTORY) llResetScript();
    }
    on_rez(integer start_param)
    {
// eyes_visible = TRUE;
SetEyeDirection();
}
timer()
{
// llSetText("O:48274(52694)/65536\nC:"+
    // (string)llGetUsedMemory()
    // +"("+(string)llGetSPMaxMemory()
    // +")/"+(string)llGetMemoryLimit()+"\nLast Message:\n"+lastmessage
    // ,<1,1,1>, 1.0);
    #ifdef can_blink
    if(need_blinking)
    {
        is_blinking = FALSE;
        if(blink_r > curr_eye_r_opening)
        {
            blink_r--;
            is_blinking = TRUE;
        }
        if(blink_l > curr_eye_l_opening)
        {
            blink_l--;
            is_blinking = TRUE;
        }
        if(is_blinking)
        {
            SetEyeShape(blink_r,1);
            SetEyeShape(blink_l,0);
            llRegionSayTo(g_ownerKey_k,nt101chanl,"blink "+ (string)blink_r + " " + (string)blink_l);
        }
        need_blinking = is_blinking;
    }
    else{
        if(llFrand(1.0) >= 0.80)
        {
            need_blinking = TRUE;
            blink_r = 3;
            blink_l = 3;
            SetEyeShape(blink_r,1);
            SetEyeShape(blink_l,0);
            llRegionSayTo(g_ownerKey_k,nt101chanl,"blink "+ (string)blink_r + " " + (string)blink_l);
        }   
    }   
    #endif
    if(responds_to_typing)
    {
        integer mew = llGetAgentInfo(g_ownerKey_k);
        if(!is_typing && (mew & AGENT_TYPING)==AGENT_TYPING)
        {
            is_typing = TRUE;
            backup_shell = curr_face_shape;
        }
        else
        if(is_typing && (mew & AGENT_TYPING)!=AGENT_TYPING)
        {
            is_typing = FALSE;
            SetFaceShape(backup_shell);
        }
        if(is_typing)
        {
            integer a = random_integer(0,12);
            while (a == curr_face_shape) a = random_integer(0,12);
            SetFaceShape(a);
        }
    }
// */
// db("Duration: " + (string)(llGetTime() - testTime));
if(need_blinking)
llSetTimerEvent(1.0/8);
else
llSetTimerEvent(1.0);
Blitz();
}
listen(integer ch,string name,key id,string msg)
{
    if(llGetOwnerKey(id) !=g_ownerKey_k)
    return;
    llResetTime();
    lastmessage=msg;
    list data = llParseStringKeepNulls(msg,[":"],[]);
    string cmd = llList2String(data,0);
    string param1 = llList2String(data,1);
    string param2 = llList2String(data,2);
    string param3 = llList2String(data,3);
    if(msg == "Y!"){
        eyes_visible = FALSE;
        first_pass = TRUE;
        SetFaceShape(curr_face_shape);
        first_pass = FALSE;
    }
    else if(msg == "N!"){
        eyes_visible = TRUE;
        first_pass = TRUE;
        SetFaceShape(curr_face_shape);
        first_pass = FALSE;
    }
    else if(cmd == "")
    {
        db("reeeeeeeeeeeeeee '"+msg+"'");
    }
    else if(cmd == "Ears")
    {
        curr_ears_mode = (integer)param1;
        SetEarsShape(curr_ears_mode);
    }
    else if(param1 == "Lids")
    {
        if(cmd == "REye")
        {
            curr_eye_r_opening = (integer)param2;
            blink_r = curr_eye_r_opening;
            SetEyeShape(blink_l,TRUE);
        }
        else if(cmd == "LEye")
        {
            curr_eye_l_opening = (integer)param2;
            blink_l = curr_eye_l_opening;
            SetEyeShape(blink_l,FALSE);
        }
        Blitz();
    }
    else if(cmd == "Anim")
    {
        // integer cmd_c_i = (integer)param2;
        //if(param1 == "Blush")
        //{
        //    msg = "blush " + cmd_c - 1);
        //}
        //if(param1 == "Tears")
        //{
        //    msg = "tears " + (string)(cmd_c_i - 1);
        //}
        if(param1 == "Type")
        {
            if(param2 == "off")
            {
                responds_to_typing = FALSE;
            }
            if(param2 == "on")
            {
                responds_to_typing = TRUE;
            }
        }
        else if(param1 == "Brows")
        {
            /* The faces aren't ordered in the command order FIXME: Rename meshes instead */
            /* TODO: inline this in the params contruction instead of calling the function 3 times */
            if("1" == param2) // angry
            {
                SetFaceTexture("brow1",c_skin,1);
                SetFaceTexture("brow2",c_skin,0);
                SetFaceTexture("brow0",c_skin,0);
            }
            else if("2" == param2) // normal
            {
             SetFaceTexture("brow0",c_skin,1);
             SetFaceTexture("brow1",c_skin,0);
             SetFaceTexture("brow2",c_skin,0);
         }
            else if("3" == param2) // Raised
            {
             SetFaceTexture("brow2",c_skin,1);
             SetFaceTexture("brow1",c_skin,0);
             SetFaceTexture("brow0",c_skin,0);
         }
     }
     else if(param1=="Blush")
     {
        SetBlushType(((integer)param2)-1);
    }
    else if(param1=="Tears")
    {
        SetTearsType(((integer)param2)-1);
    }
}
else if(cmd == "Exp")
{
    /* BUGFIX: Do not allow tongue to poke out unless the mouth is open wide enough (state 12 and 13 on stock hud) */
    integer p_i = (integer)param1;
    if(param1 == "14a")
    {
     tongue_out = 1;
 }
 else if(param1 == "14b")
 {
     tongue_out = 0;
 }
 //else if(p_i < 13)
 //{
 //   tongue_out = 0;
 //}
 SetFaceShape(p_i);
 Blitz();
        }
    /* TODO: Finish to re-implement
    else if(cmd == "precisepos")
    {
        // Shell Eyes position
    }
    else if(cmd == "eRoll")
    {
        if(param1 == "0"){msg = "reset";}
        if(param1 == "1"){msg = "up both 2";}
        if(param1 == "11"){msg = "up both 4";}
        if(param1 == "3"){msg = "down both 2";}
    }
    else if(cmd=="dilate")
    {
        pupils_dilated = (integer)param1;
        if(pupils_dilated==1)
        {
            override_l=100;
            override_r=100;
        }
        else
        {
            override_l=-1;
            override_r=-1;
        }
        SetEyeDirection();
    }
    else if(cmd == "reset")
    {
        if(msg == "reset" || param1 == "L")
        { eye_l_pos = <0,0,0>; }
        if(msg == "reset" || param1 == "R")
        { eye_r_pos = <0,0,0>; }
        SetEyeDirection();
    }
    else if(cmd == "up")
    {
        if(param1 == "R" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_r_pos.y = (integer)param2;
            }
            else
            {
                eye_r_pos.y -= 1;
            }
        }
        if(param1 == "L" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_l_pos.y = (integer)param2;
            }
            else
            {
                eye_l_pos.y -= 1;
            }
        }
        if(eye_r_pos.y < -6)
        {eye_r_pos.y = -6;}
        if(eye_r_pos.y > 6)
        {eye_r_pos.y = 6;}
        if(eye_l_pos.y < -6)
        {eye_l_pos.y = -6;}
        if(eye_l_pos.y > 6)
        {eye_l_pos.y = 6;}
        SetEyeDirection();
    }
    else if(cmd == "down")
    {
        if(param1 == "R" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_r_pos.y = (integer)param2;
            }
            else
            {
                eye_r_pos.y += 1;
            }
        }
        if(param1 == "L" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_l_pos.y = (integer)param2;
            }
            else
            {
                eye_l_pos.y += 1;
            }
        }
        if(eye_r_pos.y < -6)
        {eye_r_pos.y = -6;}
        if(eye_r_pos.y > 6)
        {eye_r_pos.y = 6;}
        if(eye_l_pos.y < -6)
        {eye_l_pos.y = -6;}
        if(eye_l_pos.y > 6)
        {eye_l_pos.y = 6;}
        SetEyeDirection();
    }
    else if(cmd == "left")
    {
        if(param1 == "R" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_r_pos.x = (integer)param2;
            }
            else
            {
                eye_r_pos.x -= 1;
            }
        }
        if(param1 == "L" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_l_pos.x = (integer)param2;
            }
            else
            {
                eye_l_pos.x -= 1;
            }
        }
        if(eye_r_pos.x < -5)
        {eye_r_pos.x = -5;}
        if(eye_r_pos.x > 5)
        {eye_r_pos.x = 5;}
        if(eye_l_pos.x < -5)
        {eye_l_pos.x = -5;}
        if(eye_l_pos.x > 5)
        {eye_l_pos.x = 5;}
        SetEyeDirection();
    }
    else if(cmd == "right")
    {
        if(param1 == "R" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_r_pos.x = (integer)param2;
            }
            else
            {
                eye_r_pos.x += 1;
            }
        }
        if(param1 == "L" || param1 == "both" || param1 == "")
        {
            if(param2 != "")
            {
                eye_l_pos.x = (integer)param2;
            }
            else
            {
                eye_l_pos.x += 1;
            }
        }
        if(eye_r_pos.x < -5)
        {eye_r_pos.x = -5;}
        if(eye_r_pos.x > 5)
        {eye_r_pos.x = 5;}
        if(eye_l_pos.x < -5)
        {eye_l_pos.x = -5;}
        if(eye_l_pos.x > 5)
        {eye_l_pos.x = 5;}
        SetEyeDirection();
    }
    else if(cmd=="size")
    {
        Teeny = (integer)param1;
        SetEyeDirection();
    }
    //else if(cmd=="tongue")
    //{
    //    tongue_out = (integer)param1;
    //    SetFaceShape(curr_face_shape);
    //}
    else if(cmd=="derpy")
    {
        Derpy = (integer)param1;
        SetEyeDirection();
    }
    */

    else if(cmd=="light")
    {
        flstatus = (integer)param1;
        Light(flstatus);
    }
    // llOwnerSay("Listen event took " + (string)llGetTime()+" to complete");
}
state_entry()
{
    llScriptProfiler(PROFILE_SCRIPT_MEMORY);
    llSetText("",ZERO_VECTOR,0);
    Blitz();
// llSetLinkTexture(LINK_SET, TEXTURE_BLANK,ALL_SIDES);
/*  Gut Utilizator's scripts */
integer n = llGetInventoryNumber(INVENTORY_SCRIPT);
do
{
    string item = llGetInventoryName(INVENTORY_SCRIPT, n);
    if(llGetSubString(item, 0, 4) == "[M3V ")
    {
        db("Deleting " + item);
        llRemoveInventory(item);
    }
    n--;
    }while (n > 1);
    g_ownerKey_k = llGetOwner();
    Probe();
    /* Apply face textures */
    // SetFaceTexture("root",c_skin,1);
    // integer i;
    // for (i=0; i<3; i++){
    //     SetFaceTexture("brow"+(string)i,c_skin,0);
    // }
    // for (i=1; i<=9; i++)
    // SetFaceTexture("e0"+(string)i,c_skin,0);
    // Blitz();
    // for (i=10;i<=13;i++)
    // SetFaceTexture("e" +(string)i,c_skin,0);
    // Blitz();
    // SetFaceTexture("ears" ,c_skin,0);
    // SetFaceTexture("eyes",c_eye_sclera,0);
    // Blitz();
    // SetFaceShape(curr_face_shape);
    // SetEyeShape(1,1);
    // SetEyeShape(1,0);
    // Blitz();
    // SetBrowShape(curr_brow_shape);
    // SetEarsShape(curr_ears_mode);
    // Blitz();
    // SetBlushType(curr_blush_mode);
    // SetTearsType(curr_tears_mode);
    // Blitz();
    // Light(flstatus);
    // SetEyeDirection();
    // Blitz();
    llListen(-34525470,"",NULL_KEY,"");
    /*Send updates to other parts using the hud format so that it sync properly: e.g. fangs*/
// llWhisper(-34525470,"Exp:stock_anim_id" + (string)(curr_face_shape));
first_pass = 0;
nt101chanl = (integer)("0x"+llGetSubString((string)g_ownerKey_k,-8,-1));
llListen(nt101chanl,"",NULL_KEY,"");
llRegionSayTo(g_ownerKey_k,nt101chanl,"E?");
TIMER_ELAPSED = llGetUnixTime();
llSetTimerEvent(1.0);
}
}
/*
Changelog:
Xenhat Liamano:
2017-12-02T21:15:14-05:00:
- Begin re-wring the animation system
2017-04-25 11:46:11 PM:
- Replace most read-only globals by preprocessor (Firestorm or else) directives
- Re-indent entire script
- change comment format for problematic blocks
2/22/2017 8:50:32 PM
- Update face code for M3V (v.1.12.51)
2/22/2017 8:36:36 PM
- Fix eyelashes issues (hacky alpha fix was bad)
2016-11-26 8:38:05 AM
- Revert sclera to white to fix cavities, lol
2016-10-07 7:11:58 AM
- Some optimizations in the listener/parser
2016-10-03 12:10:50 AM
- Fix sclera not hiding/showing properly
- re-add sclera color
9/11/2016 7:05:08 AM
- reset eyes visibility on attach
8/20/2016 7:21:38 PM
- personal iris colors.
8/19/2016 7:02:40 PM
- Ping part 2; show on detach
8/19/2016 6:48:52 PM
- Re-implemented NT-101 ping
8/17/2016 1:34:49 AM
- Fixed typo in left face texture definition
7/25/2016 10:18:41 PM
- Fixed eyelids
7/25/2016 8:41:32 PM
- Fixed bottom eyelashes face mapping
7/20/2016 1:03:35 AM
- Clean up useless memory bloat from unused parameters
and needless list copying.
7/20/2016 12:56:54 AM
- Clean up a lot of necessary Blitz() calls
7/20/2016 12:33:32 AM
- Somewhat restored the left side texturing interdependency
- Mostly restored from-scratch blink texturing
5/16/2016 12:38:38 PM
- Added a few speed hacks for now
- Added logic to use the hud's Typing state setting
- Added more debug text
- Added real memory usage to debug hovertext
- Added sclera coloration
- Fixed a few shell logic, needs more field testing.
- Fixed default expression to be the same as the stock HUD
- Fixed eye alpha glitch by using alpha masking
- Fixed eyebrow state order being different than the stock HUD
- Fixed some shell coloring
- Fixed tongue behavior
- Re-ordered some settings to ease modding.
- Removed empty list check in wert function.
- Removed extraneous parameter in SetFaceTexture
- Removed one-time use active boolean
- Removed one-time use DebugText function
- Removed one-time use InitialSetup function
- Removed one-time use ProcessAsDefaultHead function
- Removed one-time use SetEyelidTexture function
- Removed one-time use SetTeethShape function
- Removed one-time use Sync function
- Restored independent eyebrow and eyelash colors
4/28/2016 7:28:07 PM
- Fixed Project Arousal/stock hud parsing
- The Project arousal M3/Kemono/Venus expression plugins contains a leading column
which confused our reverse-engineered parser.
Loki (LogicShrimp):
?/?/? ?:?:?
- Added Stock hud and Project Arousal support
*/
/*  These settings should be overriden by the hud settings. */
/*  TODO: Add parsing for what's missing. */
/*  TODO: Reverse-engineer the skin applier. */
/*  - Xenhat */
/* NOTE: The default settings for the Venus head (from the hud) are:
'FLight:off'
'Anim:Type:off'
'Anim:VChat:off'
'Anim:Emote:off'
'Ears:1'
'LEye:glow:off'
'REye:glow:off'
'LEye:fullb:off'
'REye:fullb:off'
'LEye:intense:off'
'REye:intense:off'
'eSize:1'
'eRoll:0'
'eSize:1'
'eRoll:0'
'Anim:Brows:2'
'LEye:Lids:1'
'REye:Lids:1'
'Anim:Blush:1'
'Anim:Tears:1'
'Exp:2'
*/
#define ALREADY_INCLUDED
