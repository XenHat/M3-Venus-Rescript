/* M3+ VENUS HEAD AFTERMARKET CONTROLLER. [1147 LINES]
Core Design by: Motoko Henusaki II
Additional work by: LogicShrimp & Xenhat Liamano
LastMod: 2017-04-25 11:46:01 PM
TODO:
- Deduplicate texturing logic to avoid texturing
the same face more than once or twice
*/
// #define debug_mode
//#define ADAPTIVE_IRISES /*  TRUE to use outer eye layers for adaptive pupils. */
#define linear_pupil_response
#define can_blink

integer responds_to_typing = TRUE; /*  TRUE if head can respond to typing. */
integer eyes_visible = TRUE;
#define blink_mult 2
/*  Textures */
//Catia/Xenhat
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
integer curr_face_shape = 1;
integer curr_brow_shape = 0;
integer curr_eye_r_opening = 0;
integer curr_eye_l_opening = 0;
integer curr_ears_mode = 0;
integer curr_blush_mode = 0;
integer curr_tears_mode = 0;
integer tongue_out = FALSE;
integer flstatus = FALSE;
integer Derpy = 0;
integer Teeny = 0;
integer first_pass = 1;
list prims = [];
list wert = [];
float pup_sc_r = 0.3;
float pup_sc_l = 0.3;
/*  SC() - scales 0-100 to pupil texture UV limits. */
float min = 1.5;
float max = 0.3;
float rio = 75;
integer backup_shell = 0;
integer is_typing = 0;
integer blink_l = 3;
integer blink_r = 3;
integer need_blinking = TRUE;
integer channel = -1;
integer lh = -1;
integer lh2 = -1;
vector eye_r_pos = <0,0,0>;
vector eye_l_pos = <0,0,0>;
integer pupils_dilated = 0;
/*  timer modularity */
integer TIMER_ELAPSED;
key g_ownerKey_k;
#define NO -1
#define stride 7
Probe()
{
    prims = ["root",1,01,00,02,NO,NO];
    /* note: face 00 on root mesh = eyebags */
    integer i = llGetNumberOfPrims();
    string s;
    while (i > 1)
    {
        s = llGetLinkName(i);
        if(s == "facelight")
        { prims += [s, i,NO,NO,NO,NO,NO]; }
        /* skinR, skinL, lashR, lashL,Corner. */
        if(s == "blink0")
        { prims += [s, i,00,03,02,04,01]; }
        if(s == "blink1")
        { prims += [s, i,00,03,02,04,01]; }
        if(s == "blink2")
        { prims += [s, i,00,03,02,04,01]; }
        if(s == "blink3")
        { prims += [s, i,00,03,02,04,01]; }
        /* === Notes about the "eyes" mesh === */
        /* Face 0: Pupil Right */
        /* Face 1: Teeth */
        /* Face 2: Teeth */
        /* Face 3: Combined Upper Teeth and sclera (SIGH UTI) */
        /* face 4: Iris outer Left */
        /* Face 5: Pupil Right */
        /* Face 6: Tongue */
        /* Face 7: Iris outer Right */
        if(s == "eyes")
        { prims += [s, i,03,04,00,NO,NO]; } /* M3K COMPAT* sclera,eye,eye */
        if(s == "eyes")
        { prims += ["teeth", i,01,02,NO,NO,NO]; } /* M3K COMPAT* teeth,teeth,sclera */
        if(s == "eyes")
        { prims += ["tongue",i,06,NO,NO,NO,NO]; } /* *M3K COMPAT* tongue */
        if(s == "ears")
        { prims += [s, i,02,03,01,00,NO]; } /* earHR,earER,earHL,earEL */
        if(s == "brow0")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, broww  */
        if(s == "brow1")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, broww */
        if(s == "brow2")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, broww */
        if(s == "e01")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e02")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e03")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, teefs */
        if(s == "e04")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL */
        if(s == "e05")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e06")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e07")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, teefs */
        if(s == "e08")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e09")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e10")
        { prims += [s, i,00,03,02,NO,NO]; } /* skinR, skinL, teefs */
        if(s == "e11")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e12")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        if(s == "e13")
        { prims += [s, i,00,02,NO,NO,NO]; } /* skinR, skinL */
        i--;
    }
    prims = llListSort(prims,stride,TRUE);
#ifdef debug_mode
    llWhisper(DEBUG_CHANNEL, llList2CSV(prims));
#endif
}
SetFaceTexture(string what,vector color,float visible)
{
#ifdef debug_mode
    llWhisper(PUBLIC_CHANNEL,"SetFaceTexture in == '"
        + what + ", "+ (string)color + "," + (string)visible + ","
        + (string)eyes_visible + "'");
#endif
    integer lin = LN(what);
    if(lin < 1) return;
    integer face0 = FI(what,0);
    integer face1 = FI(what,1);
    integer face2 = FI(what,2);
    integer face3 = FI(what,3);
    integer face4 = FI(what,4);
    /* Save tremendous amounts of memory by avoiding list copy-and-addition */
    Blitz();
    wert += [PRIM_LINK_TARGET,lin,PRIM_COLOR,face0,color,visible,PRIM_COLOR,face1,color,visible];
    if(what == "eyes")
    {
    }
    else {
        /* TODO: Check if we can use the textures with alpha for everything but the blink prims instead. - Xenhat */
        if(llSubStringIndex(what,"b")==0)
        { /* blink* prims */
            wert += [PRIM_TEXTURE,face0,t_face_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1,t_face_l,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
        }
        if(what == "root")
        {
            wert += [PRIM_TEXTURE,face0 ,t_face_noshell_nolid_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1 ,t_face_noshell_nolid_l,<1,1,1>,<0,0,0>,0];
        }
        /* The actual eyelashes "hair" */
        wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
        wert += [PRIM_COLOR,face2,color,visible];
        if(llSubStringIndex(what,"e")==0)
        {
            /* Teeth */
            wert += [PRIM_TEXTURE,face2,t_face_r,<1,1,1>,<0,0,0>,0];
            /* Actual mouth shells */
            wert += [PRIM_TEXTURE,face0,t_face_r,<1,1,1>,<0,0,0>,0];
            wert += [PRIM_TEXTURE,face1,t_face_l,<1,1,1>,<0,0,0>,0];
        }
        if(llSubStringIndex(what,"brow")==0)
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
        if(llSubStringIndex(what,"ears")==0)
        {
            wert += [PRIM_COLOR,face2,color,visible];
            wert += [PRIM_COLOR,face3,color,visible];
            wert += [PRIM_TEXTURE,face3,t_face_r,<1,1,1>,<0,0,0>,0];
            /* Remove spec */
            /* wert += [PRIM_SPECULAR,face2,NULL_KEY,<1,1,1>,<0,0,0>,0,<1,1,1>,0,0]; */
            /* wert += [PRIM_SPECULAR,face3,NULL_KEY,<1,1,1>,<0,0,0>,0,<1,1,1>,0,0]; */
        }
    }
    Blitz();
}
Blitz()
{
    if(wert!=[])
    {
        llSetLinkPrimitiveParamsFast(2,wert);
        wert=[];
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
SetEyeShape(integer idx,integer right)
{
    /*  TODO: Speed this up a lot. Blinking is too slow. */
    string id_s = (string)idx;
    SetEyeDirection();
    /*  Save construction/deconstruction overhad by initializing here */
    string what = "blink"+id_s;
    float visible;
    integer lin = LN(what);
    if(lin < 1) return;
    integer idx_new = 0; if(!right) idx_new++;
    integer faceR;
    integer faceL;
    integer invisible;
    /*  Empty change list right before to ensure minimal parameter batch */
    /*  Blitz(); */
    integer i = 0;
    /*  llWhisper(DEBUG_CHANNEL, "SetEyeShape::while()"); */
    while (i <= 3)
    { /*  Reminder: This iterates through faces, not meshes */
        what = "blink"+(string)i;
        visible = (i==idx);
        lin = LN(what);
        if(lin < 1) return;
        idx_new = 0; if(!right) idx_new++;
        faceR = FI(what,idx_new+0);
        faceL = FI(what,idx_new+2);
        invisible = FI(what,6);
        /*  llOwnerSay("Applying texture on " + (string)what+"("+(string)lin+"), face "+(string)idx_new); */
        wert += [PRIM_LINK_TARGET,lin,PRIM_COLOR,faceR,c_skin,visible,
        PRIM_COLOR,faceL,c_eyelash,visible];
        if(3 == i)
        {
            /*  "closed" eyelashes needs a special mapping, because reasons. */
            wert += [PRIM_TEXTURE,faceL,t_eyelash,<1,1,1>,<-0.300,0,0>,0];
        }
        else
        {
            /*  Normal eyelash faces */
            wert += [PRIM_TEXTURE,faceL,t_eyelash,<1,1,1>,<0,0,0>,0];
        }
        /*  Fix alpha glitches */
        // wert += [PRIM_ALPHA_MODE, faceR, PRIM_ALPHA_MODE_BLEND, 1, PRIM_ALPHA_MODE, faceL, PRIM_ALPHA_MODE_BLEND, 1
        // ,PRIM_TEXTURE,invisible,TEXTURE_TRANSPARENT,<1,1,1>,<0,0,0>,0.0
        // ,PRIM_ALPHA_MODE, 1, PRIM_ALPHA_MODE_MASK,1 // should always be face 1. */
        // ];
        i++;
    }
}
float SC(float a)
{
    float aMax = 100.0;
    float aMin = 0.0;
    a = CIROF(a);
    return (a/((aMax-aMin)/(max-min)))+min;
}
/*  CIROF() - Linear pupil response. Needed by SC(). */
float CIROF(float in)
{
    if(in < 0) in = 0;
    if(in > 100) in = 100;
    float mas = in;
#ifdef linear_pupil_response
    float Uran = 100-rio; /*  Upper range. */
    float Lran = rio; /*  Lower range. */
    if(in == 50)
    {
        mas = rio;
    }
    else
    if(in > 50)
    {
        mas = (in - 50);
        mas = rio + (mas / 50 * Uran);
    }
    else
    if(in < 50)
    {
        mas = (in / 50 * Lran);
    }
#endif
    return mas;
}
SetEyeDirection()
{
    integer lin = LN("eyes");
    if(lin < 1) return;
    integer face1 = FI("eyes",1);
    integer face2 = FI("eyes",2);
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

         if(Teeny)
        {
            scale = 1.5; /*  Small irises! */
        }
            list chg = [
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
    wert += [PRIM_LINK_TARGET,lin]+chg;
    chg = [];
        // }
}
vector CFE(vector fwd)
{
    rotation res;
    fwd = llVecNorm(fwd);
    vector up = <0.0,1.0,0.0>;
    vector lf = llVecNorm(up%fwd);
    fwd = llVecNorm(lf%up);/*  else up = llVecNorm(fwd%lf); */
    res = llAxes2Rot(fwd,lf,up);
    if(res.z > 1.0) res.z = 1.0; /*  Just in case! */
    if(res.z < -1.0) res.z = -1.0; /*  Just in case! */
    return llVecNorm(<1,0,0>*res); /*  Return adjusted vector. */
}
SetFaceShape(integer idx)
{
    /*  TODO: Change the face IDs to match the HUD ones and avoid all this duplicated logic. */
    /*  Stock IDs appear to start at 1, Motoko' appear to start at 0. */
    if(idx < 0 ) idx = 0;
    if(idx > 12) idx = 12;
    string id = (string)(idx+1);
    if((integer)id<10)
    { id = "0"+id; }
    SetFaceTexture("e"+id,c_skin,TRUE);
    /*  Fix up previous face shell. */
    if(idx != curr_face_shape)
    {
        id = (string)(curr_face_shape+1);
        if((integer)id<10)
        { id = "0"+id; }
        SetFaceTexture("e"+id,c_skin,FALSE);
    }
    curr_face_shape = idx;
    /*  Do teeth. */
    integer mode = 0;
    if(11 == curr_face_shape || 12 == curr_face_shape) mode = 1;
    integer lin = LN("eyes");
    if(lin < 1) return;
    integer lintong = LN("tongue");
    if(lintong < 1) return;
    integer linteet = LN("teeth");
    if(linteet < 1) return;
    integer face1 = FI("tongue",0); /*  tongue */
    integer face2 = FI("teeth",0);
    integer face3 = FI("teeth",1);
    integer sclera1 = FI("eyes",0); /*  upper teeth, also eye sclera */
    integer sclera2 = FI("eyes",1); /*  upper teeth, also eye sclera */
    integer sclera3 = FI("eyes",2); /*  upper teeth, also eye sclera */
    if(0 == mode) tongue_out = FALSE;
    list chg = [
    PRIM_LINK_TARGET,lintong,
    PRIM_COLOR,face1,c_skin,tongue_out,
    PRIM_LINK_TARGET,linteet,
    PRIM_COLOR,face2,c_skin,mode==1, /*  teeth 1 */
    PRIM_COLOR,face3,c_skin,mode==0 /*  teeth 2 */
    /*  PRIM_COLOR,face4,c_skin,TRUE // teeth base */
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
    /* Send updates to other parts using the hud format so that it sync properly: e.g. fangs */
    /*  We send this before changing the mouth shells so that it happens roughly at the same time */
    if((llGetUnixTime() - TIMER_ELAPSED) >= 5) /*  every 5 sec at least */
    {
        /*  if(!is_typing) */
        /*  todo: remove me after confirmed working */
        integer stock_id = curr_face_shape + 1;
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
            llWhisper(-34525470,"Exp:" + (string)(stock_id));
            TIMER_ELAPSED = llGetUnixTime();
        }
    }
    /*  Force sync now. */
    /*  Blitz(); */
    chg = [];
}
string loading_bar = "";
loadingbar()
{
    llSetText(loading_bar, <0,1,1>, 1.0);
    loading_bar += ".";
}
SetBrowShape(integer idx)
{
    string id = (string)idx;
    integer i = 0;
    while (i < 3)
    { /*  0,1,2 */
        id = (string)i;
        SetFaceTexture("brow"+id,c_skin,i==idx);
        i++;
    }
}
integer FI(string what,integer index)
{
    integer i = llListFindList(prims,[what]);
    if(i > -1) return llList2Integer(prims,i+(2+index));
    return -1;
}
integer LN(string what)
{
    integer i = llListFindList(prims,[what]);
    if(i > -1) return llList2Integer(prims,i+1);
    return -1;
}

integer random_integer(integer min, integer max)
{
    return min + (integer)(llFrand(max - min + 1));
}
blink(){

}
integer is_blinking = FALSE;
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
        // Blitz();
#ifdef can_blink
        /*  TODO: Make this a LOT faster. */
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
                llRegionSayTo(g_ownerKey_k,channel,"blink "+ (string)blink_r + " " + (string)blink_l);
            }
            need_blinking = is_blinking;
        }
        else{
            if(llFrand(1.0) >= 0.95)
            {
                need_blinking = TRUE;
                blink_r = 3;
                blink_l = 3;
                SetEyeShape(blink_r,1);
                SetEyeShape(blink_l,0);
                // Blitz();
                llRegionSayTo(g_ownerKey_k,channel,"blink "+ (string)blink_r + " " + (string)blink_l);
            }
        }
#endif /*  can_blink */
        // float testTime = llGetTime();
        if(responds_to_typing)
        {
            integer mew = llGetAgentInfo(g_ownerKey_k);
            if((!is_typing) && ((mew & AGENT_TYPING)==AGENT_TYPING))
            {
                is_typing = TRUE;
                backup_shell = curr_face_shape;
            }
            else
            if((is_typing) && ((mew & AGENT_TYPING)!=AGENT_TYPING))
            {
                is_typing = FALSE;
                SetFaceShape(backup_shell);
                // Blitz();
            }
            if(is_typing)
            {
                integer a = random_integer(0,12);
                while (a == curr_face_shape) a = random_integer(0,12);
                SetFaceShape(a);
                // Blitz();
            }
        }
        Blitz();
        // llOwnerSay("Duration: " + (string)(llGetTime() - testTime));
        if(need_blinking)
            llSetTimerEvent(1.0/8);
        else
            llSetTimerEvent(1.0);
    }
    listen(integer ch,string name,key id,string msg)
    {
        /*  clean up unused vars */
        if(llGetOwnerKey(id) !=g_ownerKey_k)
        {
            return;
        }
        if(ch != channel)
        {
            /*  hack in and intercept NT101 next-gen (lol) ping */
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
            /*  ProcessAsDefaultHead() inlined */
            list data = llParseStringKeepNulls(msg,[":"],[]);
            string cmd_a = llList2String(data,0);
            string cmd_b = llList2String(data,1);
            string cmd_c = llList2String(data,2);
            string cmd_d = llList2String(data,3);
            /*  Workaround for Caeil's message format. Sigh. */
            if(cmd_a == "")
            {
                cmd_a = cmd_b;
                cmd_b = cmd_c;
                cmd_c = cmd_d;
                cmd_d = llList2String(data,4);
            }
            if(cmd_a == "Ears"){msg = "ears " + cmd_b;}
            if(llGetSubString(cmd_a,1,3) == "Eye")
            {
                if(cmd_b == "Lids")
                {
                    /* msg = "eyelids " + llGetSubString(cmd_a,0,0) + " " + (string)((integer)cmd_c - 1); */
                    msg = "eyelids both " + (string)((integer)cmd_c - 1);
                }
            }
            if(cmd_a == "Anim")
            {
                integer cmd_c_i = (integer)cmd_c;
                if(cmd_b == "Brows")
                {
                    /* Reminder: As per the M3V Venus HUD behavior, the mappings are the following: */
                    /* 3 = arched */
                    /* 1 = frowned */
                    /* 2 = flat */
                    msg = "brows ";
                    /*  Confused? https://en.wikipedia.org/wiki/Yoda_conditions */
                    if(3 == cmd_c_i)
                    {
                        msg += "2";
                    }
                    if(1 == cmd_c_i)
                    {
                        msg += "1";
                    }
                    if(2 == cmd_c_i)
                    {
                        msg += "0";
                    }
                    /* msg = "brows " + (string)((integer)cmd_c - 1); // WRONG! */
                }
                if(cmd_b == "Blush")
                {
                    msg = "blush " + (string)(cmd_c_i - 1);
                }
                if(cmd_b == "Tears")
                {
                    msg = "tears " + (string)(cmd_c_i - 1);
                }
                /*  Toggle typing preference */
                if(cmd_c == "Type")
                {
                    if(cmd_d == "off")
                    {
                        responds_to_typing = FALSE;
                    }
                    if(cmd_d == "on")
                    {
                        responds_to_typing = TRUE;
                    }
                }
            }
            if(cmd_a == "Exp")
            {
                integer cmd_b_i = (integer) cmd_b;
                /*  Do not allow tongue to poke out unless the mouth is open wide enough (state 12 and 13 on stock hud) */
                if(cmd_b_i < 14)
                {
                    tongue_out = 0;
                    msg = "face " + (string)(cmd_b_i - 1);
                }
                if(cmd_b == "14a") /*  Tongue out */
                {
                    msg = "tongue 1";
                }
                if(cmd_b == "14b") /*  Tongue in */
                {
                    msg = "tongue 0";
                }
            }
            if(cmd_a == "eRoll")
            {
                if(cmd_b == "0"){msg = "reset";}
                if(cmd_b == "1"){msg = "up both 2";}
                if(cmd_b == "11"){msg = "up both 4";}
                if(cmd_b == "3"){msg = "down both 2";}
            }
        }
        list w = llParseString2List(msg,[" "],[]);
        string c = llList2String(w,0);
        string p = llList2String(w,1);
        string p2 = llList2String(w,2);
        /* llOwnerSay(msg); */
        if(c == "ears")
        {
            if(p != "")
            {
                curr_ears_mode = (integer)p;
            }
            else
            {
                curr_ears_mode++;
            }
            if(curr_ears_mode > 2) curr_ears_mode = 0;
            SetEarsShape(curr_ears_mode);
        }
        if(c=="dilate")
        {
            pupils_dilated = (integer)p;
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
        if(c == "eyelids")
        {
            if(p == "R" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    curr_eye_r_opening = (integer)p2;
                }
                else
                {
                    curr_eye_r_opening++;
                }
                if(curr_eye_r_opening > 3) curr_eye_r_opening = 0;
                blink_r = curr_eye_r_opening;
                SetEyeShape(curr_eye_r_opening,1);
            }
            if(p == "L" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    curr_eye_l_opening = (integer)p2;
                }
                else
                {
                    curr_eye_l_opening++;
                }
                if(curr_eye_l_opening > 3)
                {
                    curr_eye_l_opening = 0;
                }
                blink_l = curr_eye_l_opening;
                SetEyeShape(curr_eye_l_opening,0);
            }
        }
        if(c == "reset")
        {
            if(msg == "reset" || p == "L")
            { eye_l_pos = <0,0,0>; }
            if(msg == "reset" || p == "R")
            { eye_r_pos = <0,0,0>; }
            SetEyeDirection();
        }
        if(c == "up")/* If command starts with "up" */
        {
            if(p == "R" || p == "both" || p == "")/* If first param is "R" or "both" */
            {
                if(p2 != "")/* If second param exists, set eye_r_pos.y equal to it. */
                {
                    eye_r_pos.y = (integer)p2;
                }
                else
                {
                    eye_r_pos.y -= 1;
                }
            }
            if(p == "L" || p == "both" || p == "")/* If first param is "L" or "both" */
            {
                if(p2 != "")/* If second param exists, set eye_l_pos.y equal to it. */
                {
                    eye_l_pos.y = (integer)p2;
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
        if(c == "down")
        {
            if(p == "R" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_r_pos.y = (integer)p2;
                }
                else
                {
                    eye_r_pos.y += 1;
                }
            }
            if(p == "L" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_l_pos.y = (integer)p2;
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
        if(c == "left")
        {
            if(p == "R" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_r_pos.x = (integer)p2;
                }
                else
                {
                    eye_r_pos.x -= 1;
                }
            }
            if(p == "L" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_l_pos.x = (integer)p2;
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
        if(c == "right")
        {
            if(p == "R" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_r_pos.x = (integer)p2;
                }
                else
                {
                    eye_r_pos.x += 1;
                }
            }
            if(p == "L" || p == "both" || p == "")
            {
                if(p2 != "")
                {
                    eye_l_pos.x = (integer)p2;
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
        /*  Abbreviated commands, modified, from original proto. */
        if(c=="size")
        {
            Teeny = (integer)p;
            SetEyeDirection();
        }
        if(c=="tongue")
        {
            tongue_out = (integer)p;
            SetFaceShape(curr_face_shape);
        }
        if(c=="derpy")
        {
            Derpy = (integer)p;
            SetEyeDirection();
        }
        if(c == "face")
        {
            integer tmp_curr_face_shape = curr_face_shape;
            if(p != "")
            {
                tmp_curr_face_shape = (integer)p;
            }
            else
            {
                tmp_curr_face_shape++;
            }
            if(tmp_curr_face_shape > 12 || tmp_curr_face_shape < 0){tmp_curr_face_shape = 0;}
            SetFaceShape(tmp_curr_face_shape);
        }
        if(c == "brows")
        {
            if(p != "")
            {
                curr_brow_shape = (integer)p;
            }
            else
            {
                curr_brow_shape++;
            }
            if(curr_brow_shape > 2 || curr_brow_shape < 0){ curr_brow_shape = 0;}
            SetBrowShape(curr_brow_shape);
        }
        if(c=="blush")
        {
            if(p != "")
            {
                curr_blush_mode = (integer)p;
            }
            else
            {
                curr_blush_mode++;
            }
            if(curr_blush_mode > 3 || curr_blush_mode < 0){ curr_blush_mode = 0;}
            SetBlushType(curr_blush_mode);
        }
        if(c=="tears")
        {
            if(p != "")
            {
                curr_tears_mode = (integer)p;
            }
            else
            {
                curr_tears_mode++;
            }
            if(curr_tears_mode > 2 || curr_tears_mode < 0){ curr_tears_mode = 0;}
            SetTearsType(curr_tears_mode);
        }
        if(c=="light")
        {
            flstatus = (integer)p;
            Light(flstatus);
        }
        Blitz();
    }
    //state_exit()
    //{
    //    llOwnerSay("I am being reset! \\o\\ /o/ \\o/ /o\\");
    //}
    state_entry()
    {
        // llSetLinkTexture(LINK_SET, TEXTURE_BLANK,ALL_SIDES);
            loadingbar();
        /*  Gut Utilizator's scripts */
        {
            string self = llGetScriptName();
            integer n = llGetInventoryNumber(INVENTORY_SCRIPT);
            while (n-- > 0)
            {
                string item = llGetInventoryName(INVENTORY_SCRIPT, n);
                if(item != self && llGetSubString(item, 0, 4) == "[M3V ")
                {
                    llOwnerSay("Deleting " + item);
                    llRemoveInventory(item);
                }
            }
        }
        loadingbar();
        /*  llSetText("",<0,0,0>,0.0); */
        g_ownerKey_k = llGetOwner();
        Probe();
        /*  TODO: Blank out faces to make sure we properly set all the required faces properly, then disable blanking */
        /*  TODO: add a setting to re-enable texturing on reset */
        /*  /* */
        /*  Scope this to automatically discard 'old_ve' when we're done with it. */
        {
            /*  TODO: Minimal re-write of texture application to remove as many texture overwrites as possible. */
            SetFaceTexture("root",c_skin,1);
            integer i;
            for (i=0; i<=3; i++)
            { SetFaceTexture("blink"+(string)i,c_skin,0); }
            for (i=0; i<=3; i++)
            { SetFaceTexture("brow"+(string)i,c_skin,0); }
            /*  TODO: Investigate need for this separation */
            for (i=1; i<=9; i++)
            { SetFaceTexture("e0"+(string)i,c_skin,0); }
            for (i=10;i<=13;i++)
            { SetFaceTexture("e" +(string)i,c_skin,0); }
            SetFaceTexture("ears" ,c_skin,0);
            /*  eyes. TEST. */
            SetFaceTexture("eyes",c_eye_sclera,0);
            /*  mouth shells */
            // eyes_visible = old_ve;
        }
        loadingbar();
        SetFaceShape(curr_face_shape);
                loadingbar();
                loadingbar();
        SetEyeShape(curr_eye_r_opening,1);
                loadingbar();
        SetEyeShape(curr_eye_l_opening,0);
                loadingbar();
        /*  forehead */
        SetBrowShape(curr_brow_shape);
                loadingbar();
        /*  ears */
        SetEarsShape(curr_ears_mode);
                loadingbar();
        /*  blush */
        SetBlushType(curr_blush_mode);
                loadingbar();
        /*  tears */
        SetTearsType(curr_tears_mode);
                loadingbar();
        Light(flstatus);
                loadingbar();
        SetEyeDirection();
                loadingbar();
        /*  Chan */

        channel = (integer)("0x"+llGetSubString((string)g_ownerKey_k,-8,-1));
        if(lh != -1)
        {
            llListenRemove(lh);
            lh = -1;
        }
        if(lh2 != -1)
        {
            llListenRemove(lh2);
            lh2 = -1;
        }
                loadingbar();
        lh = llListen(-34525470,"",NULL_KEY,"");
        lh2 = llListen(channel,"",NULL_KEY,"");
        /* Sync*/
        if(flstatus)
        {
            llWhisper(channel,"light 1");
        }
        else
        {
            llWhisper(channel,"light 0");
        }
        if(Derpy)
        {
            llWhisper(channel,"derpy 1");
        }
        else
        {
            llWhisper(channel,"derpy 0");
        }
        if(Teeny)
        {
            llWhisper(channel,"size 1");
        }
        else
        {
            llWhisper(channel,"size 0");
        }
        if(tongue_out)
        {
            llWhisper(channel,"tongue 1");
        }
        else
        {
            llWhisper(channel,"tongue 0");
        }
        if(pupils_dilated)
        {
            llWhisper(channel,"dilate 1");
        }
        else
        {
            llWhisper(channel,"dilate 0");
        }
                loadingbar();
        /*Send updates to other parts using the hud format */
        /* so that it sync properly: e.g. fangs*/
        llWhisper(-34525470,"Exp:stock_anim_id" + (string)(curr_face_shape - 1));
                loadingbar();
                loadingbar();
                loadingbar();
                loadingbar();
        first_pass = 0;
        TIMER_ELAPSED = llGetUnixTime();
        llRegionSayTo(g_ownerKey_k,channel,"E?");
        loading_bar="";
        loadingbar();
        // llSetTimerEvent(0.125);
        llSetTimerEvent(1.0);


    }
}
/*
Changelog:
Xenhat Liamano:
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
