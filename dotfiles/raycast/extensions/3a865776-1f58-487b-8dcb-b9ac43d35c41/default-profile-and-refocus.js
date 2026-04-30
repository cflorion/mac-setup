"use strict";var M=Object.create;var d=Object.defineProperty;var D=Object.getOwnPropertyDescriptor;var z=Object.getOwnPropertyNames;var W=Object.getPrototypeOf,V=Object.prototype.hasOwnProperty;var F=(e,t)=>{for(var n in t)d(e,n,{get:t[n],enumerable:!0})},$=(e,t,n,i)=>{if(t&&typeof t=="object"||typeof t=="function")for(let a of z(t))!V.call(e,a)&&a!==n&&d(e,a,{get:()=>t[a],enumerable:!(i=D(t,a))||i.enumerable});return e};var h=(e,t,n)=>(n=e!=null?M(W(e)):{},$(t||!e||!e.__esModule?d(n,"default",{value:e,enumerable:!0}):n,e)),N=e=>$(d({},"__esModule",{value:!0}),e);var q={};F(q,{default:()=>L});module.exports=N(q);var m=require("@raycast/api");var o=h(require("react")),r=require("@raycast/api");var c=h(require("node:fs")),p=h(require("node:path"));var w=require("react/jsx-runtime");function k(e,t){let n=e instanceof Error?e.message:String(e);return(0,r.showToast)({style:r.Toast.Style.Failure,title:t?.title??"Something went wrong",message:t?.message??n,primaryAction:t?.primaryAction??y(e),secondaryAction:t?.primaryAction?y(e):void 0})}var y=e=>{let t=!0,n="[Extension Name]...",i="";try{let s=JSON.parse((0,c.readFileSync)((0,p.join)(r.environment.assetsPath,"..","package.json"),"utf8"));n=`[${s.title}]...`,i=`https://raycast.com/${s.owner||s.author}/${s.name}`,(!s.owner||s.access==="public")&&(t=!1)}catch{}let a=r.environment.isDevelopment||t,f=e instanceof Error?e?.stack||e?.message||"":String(e);return{title:a?"Copy Logs":"Report Error",onAction(s){s.hide(),a?r.Clipboard.copy(f):(0,r.open)(`https://github.com/raycast/extensions/issues/new?&labels=extension%2Cbug&template=extension_bug_report.yml&title=${encodeURIComponent(n)}&extension-url=${encodeURI(i)}&description=${encodeURIComponent(`#### Error:
\`\`\`
${f}
\`\`\`
`)}`)}}};var u=require("@raycast/api");var x=h(require("node:process"),1),v=require("node:util"),b=require("node:child_process"),j=(0,v.promisify)(b.execFile);async function l(e,{humanReadableOutput:t=!0,signal:n}={}){if(x.default.platform!=="darwin")throw new Error("macOS only");let i=t?[]:["-ss"],a={};n&&(a.signal=n);let{stdout:f}=await j("osascript",["-e",e,i],a);return f.trim()}function S(e){return`
    tell application "${e}"
      set currentTab to active tab of front window
      set tabURL to URL of currentTab
      return tabURL
    end tell
  `}function E(e){return`
    tell application "${e}"
      tell front window
        set activeTabURL to URL of active tab
        return activeTabURL
      end tell
    end tell
  `}function A(e){return`
    tell application "${e}"
      activate
      delay 0.5
      
      tell application "System Events"
        keystroke "l" using {command down}
        delay 0.2
        keystroke "c" using {command down}
        delay 0.5
        key code 53
      end tell
    end tell
      
    delay 0.5
    
    set copiedURL to do shell script "pbpaste"
    
    return copiedURL
  `}function T(){return`
    tell application "System Events"
      keystroke tab using {command down}
    end tell
  `}var R=["Arc","Brave","Firefox","Firefox Developer Edition","Google Chrome","Microsoft Edge","Mozilla Firefox","Opera","QQ","Safari","Sogou Explorer","Vivaldi","Yandex","Zen","Dia"],U=`
    tell application "System Events"
      set frontApp to name of first application process whose frontmost is true
    end tell
    return frontApp
`;var B="https://meet.google.com/new",G=/^[0-9]+$/,K=500;function H(e){return R.includes(e)}function P(){let e=(0,u.getPreferenceValues)();return G.test(e.timeout)?Number.parseInt(e.timeout,10):K}function _(){return(0,u.getPreferenceValues)().preferredBrowser}function C(e){return new Promise(t=>setTimeout(t,e))}async function Z(){let e=await J();return e==="Arc"||e==="Dia"?await l(E(e)):e==="Firefox"||e==="Firefox Developer Edition"||e==="Zen"?await l(A(e)):await l(S(e))}async function J(){let e=_();return e?.name&&H(e.name)?e.name:await l(U)}async function g(){let t=(await Z()).split(",").find(n=>n.includes("meet.google.com"));return t?.includes("/new")?await g():t}async function I(){let e=_();await(0,u.open)(B,e?.name)}async function O(){await l(T())}async function L(){try{await I();let e=P();await C(e);let t=await g();await m.Clipboard.copy(t),await(0,m.showHUD)("Copied meet link to clipboard"),await O()}catch{await k("Failed to create meet link. Make sure your browser is supported and try again.")}}
