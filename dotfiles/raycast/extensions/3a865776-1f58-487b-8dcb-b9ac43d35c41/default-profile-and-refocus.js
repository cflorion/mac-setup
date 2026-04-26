"use strict";var M=Object.create;var d=Object.defineProperty;var D=Object.getOwnPropertyDescriptor;var z=Object.getOwnPropertyNames;var W=Object.getPrototypeOf,V=Object.prototype.hasOwnProperty;var F=(e,t)=>{for(var n in t)d(e,n,{get:t[n],enumerable:!0})},y=(e,t,n,i)=>{if(t&&typeof t=="object"||typeof t=="function")for(let a of z(t))!V.call(e,a)&&a!==n&&d(e,a,{get:()=>t[a],enumerable:!(i=D(t,a))||i.enumerable});return e};var h=(e,t,n)=>(n=e!=null?M(W(e)):{},y(t||!e||!e.__esModule?d(n,"default",{value:e,enumerable:!0}):n,e)),N=e=>y(d({},"__esModule",{value:!0}),e);var q={};F(q,{default:()=>L});module.exports=N(q);var m=require("@raycast/api");var o=h(require("react")),r=require("@raycast/api");var c=h(require("node:fs")),p=h(require("node:path"));var k=require("react/jsx-runtime");function x(e,t){let n=e instanceof Error?e.message:String(e);return(0,r.showToast)({style:r.Toast.Style.Failure,title:t?.title??"Something went wrong",message:t?.message??n,primaryAction:t?.primaryAction??w(e),secondaryAction:t?.primaryAction?w(e):void 0})}var w=e=>{let t=!0,n="[Extension Name]...",i="";try{let s=JSON.parse((0,c.readFileSync)((0,p.join)(r.environment.assetsPath,"..","package.json"),"utf8"));n=`[${s.title}]...`,i=`https://raycast.com/${s.owner||s.author}/${s.name}`,(!s.owner||s.access==="public")&&(t=!1)}catch{}let a=r.environment.isDevelopment||t,f=e instanceof Error?e?.stack||e?.message||"":String(e);return{title:a?"Copy Logs":"Report Error",onAction(s){s.hide(),a?r.Clipboard.copy(f):(0,r.open)(`https://github.com/raycast/extensions/issues/new?&labels=extension%2Cbug&template=extension_bug_report.yml&title=${encodeURIComponent(n)}&extension-url=${encodeURI(i)}&description=${encodeURIComponent(`#### Error:
\`\`\`
${f}
\`\`\`
`)}`)}}};var u=require("@raycast/api");var v=h(require("node:process"),1),S=require("node:util"),b=require("node:child_process"),j=(0,S.promisify)(b.execFile);async function l(e,{humanReadableOutput:t=!0,signal:n}={}){if(v.default.platform!=="darwin")throw new Error("macOS only");let i=t?[]:["-ss"],a={};n&&(a.signal=n);let{stdout:f}=await j("osascript",["-e",e,i],a);return f.trim()}function E(e){return`
    tell application "${e}"
      set currentTab to active tab of front window
      set tabURL to URL of currentTab
      return tabURL
    end tell
  `}function A(){return`
    tell application "Arc"
      tell front window
        set activeTabURL to URL of active tab
        return activeTabURL
      end tell
    end tell
  `}function T(e){return`
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
  `}function R(){return`
    tell application "System Events"
      keystroke tab using {command down}
    end tell
  `}var g=["Arc","Brave","Firefox","Firefox Developer Edition","Google Chrome","Microsoft Edge","Mozilla Firefox","Opera","QQ","Safari","Sogou Explorer","Vivaldi","Yandex","Zen","Dia"],U=`
    set cmd to "lsappinfo metainfo | grep -E -o '${g.join("|")}' | head -1"

    set frontmostBrowser to do shell script cmd

    return frontmostBrowser
`;var B="https://meet.google.com/new",G=/^[0-9]+$/,K=500;function H(e){return g.includes(e)}function P(){let e=(0,u.getPreferenceValues)();return G.test(e.timeout)?Number.parseInt(e.timeout,10):K}function _(){return(0,u.getPreferenceValues)().preferredBrowser}function C(e){return new Promise(t=>setTimeout(t,e))}async function Z(){let e=await J();return e==="Arc"?await l(A()):e==="Firefox"||e==="Firefox Developer Edition"||e==="Zen"||e==="Dia"?await l(T(e)):await l(E(e))}async function J(){let e=_();return e?.name&&H(e.name)?e.name:await l(U)}async function $(){let t=(await Z()).split(",").find(n=>n.includes("meet.google.com"));return t?.includes("/new")?await $():t}async function I(){let e=_();await(0,u.open)(B,e?.name)}async function O(){await l(R())}async function L(){try{await I();let e=P();await C(e);let t=await $();await m.Clipboard.copy(t),await(0,m.showHUD)("Copied meet link to clipboard"),await O()}catch{await x("Failed to create meet link. Make sure your browser is supported and try again.")}}
