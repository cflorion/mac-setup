"use strict";var U=Object.create;var a=Object.defineProperty;var A=Object.getOwnPropertyDescriptor;var F=Object.getOwnPropertyNames;var O=Object.getPrototypeOf,h=Object.prototype.hasOwnProperty;var E=(e,t)=>{for(var r in t)a(e,r,{get:t[r],enumerable:!0})},l=(e,t,r,p)=>{if(t&&typeof t=="object"||typeof t=="function")for(let o of F(t))!h.call(e,o)&&o!==r&&a(e,o,{get:()=>t[o],enumerable:!(p=A(t,o))||p.enumerable});return e};var M=(e,t,r)=>(r=e!=null?U(O(e)):{},l(t||!e||!e.__esModule?a(r,"default",{value:e,enumerable:!0}):r,e)),R=e=>l(a({},"__esModule",{value:!0}),e);var V={};E(V,{default:()=>v});module.exports=R(V);var n=require("@raycast/api");var s=require("@raycast/api");var m=M(require("node:process"),1),d=require("node:util"),c=require("node:child_process"),k=(0,d.promisify)(c.execFile);async function i(e,{humanReadableOutput:t=!0,signal:r}={}){if(m.default.platform!=="darwin")throw new Error("macOS only");let p=t?[]:["-ss"],o={};r&&(o.signal=r);let{stdout:P}=await k("osascript",["-e",e,p],o);return P.trim()}function f(e){return`
    tell application "${e}"
      set currentTab to active tab of front window
      set tabURL to URL of currentTab
      return tabURL
    end tell
  `}function w(e){return`
    tell application "${e}"
      tell front window
        set activeTabURL to URL of active tab
        return activeTabURL
      end tell
    end tell
  `}function g(e){return`
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
  `}var y=["Arc","Brave","Firefox","Firefox Developer Edition","Google Chrome","Microsoft Edge","Mozilla Firefox","Opera","QQ","Safari","Sogou Explorer","Vivaldi","Yandex","Zen","Dia"],x=`
    tell application "System Events"
      set frontApp to name of first application process whose frontmost is true
    end tell
    return frontApp
`;var D="https://meet.google.com/new",L=/^[0-9]+$/,C=500;function $(e){return y.includes(e)}function S(){let e=(0,s.getPreferenceValues)();return L.test(e.timeout)?Number.parseInt(e.timeout,10):C}function b(){return(0,s.getPreferenceValues)().preferredBrowser}function B(e){return new Promise(t=>setTimeout(t,e))}async function N(){let e=await Q();return e==="Arc"||e==="Dia"?await i(w(e)):e==="Firefox"||e==="Firefox Developer Edition"||e==="Zen"?await i(g(e)):await i(f(e))}async function Q(){let e=b();return e?.name&&$(e.name)?e.name:await i(x)}async function u(){let t=(await N()).split(",").find(r=>r.includes("meet.google.com"));return t?.includes("/new")?await u():t}async function T(){let e=b();await(0,s.open)(D,e?.name)}async function v(){try{await T();let e=S();await B(e);let t=await u();await n.Clipboard.copy(t),await(0,n.showHUD)("Copied meet link to clipboard")}catch{await(0,n.showToast)({style:n.Toast.Style.Failure,title:"Couldn't copy to clipboard"})}}
