"use strict";(self.webpackChunkdocusaurus=self.webpackChunkdocusaurus||[]).push([[3116],{3470:(e,t,s)=>{s.r(t),s.d(t,{assets:()=>d,contentTitle:()=>r,default:()=>h,frontMatter:()=>a,metadata:()=>o,toc:()=>l});var n=s(4848),i=s(8453);const a={sidebar_position:10},r="Ledgers",o={id:"essential-concepts/ledger",title:"Ledgers",description:'The Plutus Platform is designed to work with distributed ledgers, which we\'ll just call "ledgers" from now on.',source:"@site/docs/essential-concepts/ledger.md",sourceDirName:"essential-concepts",slug:"/essential-concepts/ledger",permalink:"/docs/essential-concepts/ledger",draft:!1,unlisted:!1,editUrl:"https://github.com/IntersectMBO/plutus/edit/master/doc/docusaurus/docs/essential-concepts/ledger.md",tags:[],version:"current",sidebarPosition:10,frontMatter:{sidebar_position:10},sidebar:"tutorialSidebar",previous:{title:"Plutus platform",permalink:"/docs/essential-concepts/plutus-platform"},next:{title:"Plutus foundation",permalink:"/docs/essential-concepts/plutus-foundation"}},d={},l=[{value:"Account-based and UTXO-based ledgers",id:"account-based-and-utxo-based-ledgers",level:2},{value:"Scripts and the Extended UTXO Model",id:"scripts-and-the-extended-utxo-model",level:2},{value:"Three arguments passed to validator scripts",id:"three-arguments-passed-to-validator-scripts",level:2},{value:"Logic of the validator script",id:"logic-of-the-validator-script",level:3},{value:"Different kinds of scripts",id:"different-kinds-of-scripts",level:2},{value:"Further reading",id:"further-reading",level:2}];function c(e){const t={a:"a",blockquote:"blockquote",em:"em",h1:"h1",h2:"h2",h3:"h3",li:"li",ol:"ol",p:"p",strong:"strong",table:"table",tbody:"tbody",td:"td",th:"th",thead:"thead",tr:"tr",ul:"ul",...(0,i.R)(),...e.components};return(0,n.jsxs)(n.Fragment,{children:[(0,n.jsx)(t.h1,{id:"ledgers",children:"Ledgers"}),"\n",(0,n.jsxs)(t.p,{children:['The Plutus Platform is designed to work with distributed ledgers, which we\'ll just call "ledgers" from now on.\nLedgers are typically ',(0,n.jsx)(t.em,{children:"implemented"})," with a blockchain, such as Cardano.\nHowever, much of the time when we are talking about ledgers, we don't care about the underlying\nimplementation, and so we will just talk about the ledger itself."]}),"\n",(0,n.jsxs)(t.blockquote,{children:["\n",(0,n.jsxs)(t.p,{children:["\ud83d\udccc"," ",(0,n.jsx)(t.strong,{children:"NOTE"})]}),"\n",(0,n.jsx)(t.p,{children:"This is not always true: applications do need to care about details of how the underlying blockchain works, because that affects behaviour such as settlement time and rollback policies.\nAs much as possible, the Plutus Application Framework tries to shield developers from this complexity, but it is not always possible."}),"\n"]}),"\n",(0,n.jsx)(t.p,{children:"In its simplest form, a ledger is a system that tracks who owns what."}),"\n",(0,n.jsx)(t.p,{children:"For example:"}),"\n",(0,n.jsxs)(t.table,{children:[(0,n.jsx)(t.thead,{children:(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.th,{children:"Owner"}),(0,n.jsx)(t.th,{children:"Balance"})]})}),(0,n.jsxs)(t.tbody,{children:[(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.td,{children:"Alice"}),(0,n.jsx)(t.td,{children:"43 USD"})]}),(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.td,{children:"Bob"}),(0,n.jsx)(t.td,{children:"12 USD"})]})]})]}),"\n",(0,n.jsxs)(t.p,{children:["Ledgers are typically transformed by performing a ",(0,n.jsx)(t.em,{children:"transaction"})," that transfers some assets from one party to another.\nIn order to be ",(0,n.jsx)(t.em,{children:"valid"}),", a transaction will have to pass some checks, such as demonstrating that the transfer is authorized by the owner of the funds.\nAfter applying a transaction (say, Alice sends Bob 5 USD), we have a new state of the ledger."]}),"\n",(0,n.jsxs)(t.table,{children:[(0,n.jsx)(t.thead,{children:(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.th,{children:"Owner"}),(0,n.jsx)(t.th,{children:"Balance"})]})}),(0,n.jsxs)(t.tbody,{children:[(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.td,{children:"Alice"}),(0,n.jsx)(t.td,{children:"38 USD"})]}),(0,n.jsxs)(t.tr,{children:[(0,n.jsx)(t.td,{children:"Bob"}),(0,n.jsx)(t.td,{children:"17 USD"})]})]})]}),"\n",(0,n.jsx)(t.h2,{id:"account-based-and-utxo-based-ledgers",children:"Account-based and UTXO-based ledgers"}),"\n",(0,n.jsxs)(t.p,{children:["There are two dominant paradigms for how to ",(0,n.jsx)(t.em,{children:"represent"})," such a system.\nThe first, account-based ledgers, model the system exactly as in our example above.\nThey keep a list of accounts, and for each account, a balance.\nA transaction simply decreases the balance of the sender, and increases the balance of the recipient."]}),"\n",(0,n.jsxs)(t.p,{children:["Account-based ledgers (such as Ethereum) are very simple to implement, but they have difficulties due to the fact that the state of an account is ",(0,n.jsx)(t.em,{children:"global"}),": all transactions that do anything with an account must touch this one number.\nThis can lead to issues with throughput, as well as ordering issues (if Alice sends 5 USD to Bob, and Bob sends 5 USD to Carol, this may succeed or fail depending on the order in which the transactions are processed)."]}),"\n",(0,n.jsxs)(t.p,{children:['The second paradigm is UTXO-based ledgers.\nUTXO-based ledgers (such as Bitcoin) represent the state of the ledger as a set of "unspent\ntransaction outputs" (UTXOs).\nA UTXO is like an envelope with some money in it: it is "addressed" to a particular party, and it contains some funds.\nA transaction ',(0,n.jsx)(t.em,{children:"spends"})," some number of UTXOs, and creates some more."]}),"\n",(0,n.jsx)(t.p,{children:"So a transaction that sends 5 USD from Alice to Bob would do so by spending some number of already-existing UTXOs belonging to Alice, and creating a new UTXO with 5 USD belonging to Bob."}),"\n",(0,n.jsxs)(t.p,{children:["UTXO-based ledgers are more complicated, but avoid some of the issues of account-based ledgers, since any transaction deals only with the inputs that it spends.\nCardano is a UTXO-based ledger, and we heavily rely on this.\nFor example, ",(0,n.jsx)(t.a,{href:"/docs/reference/glossary#hydra",children:"Hydra"}),", Cardano's scalability solution, uses the fact that independent parts of the transaction graph can be processed in parallel to improve throughput."]}),"\n",(0,n.jsx)(t.h2,{id:"scripts-and-the-extended-utxo-model",children:"Scripts and the Extended UTXO Model"}),"\n",(0,n.jsx)(t.p,{children:'UTXO-based ledgers typically start out with a very simple model of "ownership" of UTXOs.\nAn output will have a public key (strictly, the hash of a public key) attached to it, and in order to spend this output, the spending transaction must be signed by the corresponding private key.\nWe call this a "pay-to-pubkey" output.'}),"\n",(0,n.jsxs)(t.p,{children:["Cardano uses an extended model called the ",(0,n.jsx)(t.a,{href:"/docs/reference/glossary#extended-utxo-model",children:"Extended UTXO Model"})," (EUTXO).\nIn the EUTXO model, an output can be locked by (the hash of) a ",(0,n.jsx)(t.em,{children:"script"}),'.\nWe call this a "pay-to-script" output.\nA script is a ',(0,n.jsx)(t.em,{children:"program"})," that decides whether or not the transaction which spends the output is\nauthorized to do so.\nSuch a script is called a validator script, because it validates whether the spending is allowed."]}),"\n",(0,n.jsx)(t.p,{children:"A simple validator script would be one that checked whether the spending transaction was signed by a particular key\u2014this would exactly replicate the behaviour of simple pay-to-pubkey outputs.\nHowever, with a bit of careful extension, we can use scripts to let us express a large amount of useful logic on the chain."}),"\n",(0,n.jsx)(t.h2,{id:"three-arguments-passed-to-validator-scripts",children:"Three arguments passed to validator scripts"}),"\n",(0,n.jsx)(t.p,{children:"With the EUTXO model, validator scripts are passed three arguments:"}),"\n",(0,n.jsxs)(t.ol,{children:["\n",(0,n.jsxs)(t.li,{children:[(0,n.jsx)(t.strong,{children:"Datum"}),": a piece of data attached to the ",(0,n.jsx)(t.em,{children:"output"})," that the script is locking (strictly, again, just the hash is present). This is typically used to carry state."]}),"\n",(0,n.jsxs)(t.li,{children:[(0,n.jsx)(t.strong,{children:"Redeemer"}),": a piece of data attached to the ",(0,n.jsx)(t.em,{children:"input"})," that is doing the spending. This is typically used to provide an input to the script from the spender."]}),"\n",(0,n.jsxs)(t.li,{children:[(0,n.jsx)(t.strong,{children:"Context"}),': a piece of data which represents information about the transaction doing the spending. This is used to make assertions about the way the output is being sent (such as "Bob signed it").']}),"\n"]}),"\n",(0,n.jsx)(t.p,{children:"As an example, let's see how we could implement an atomic swap."}),"\n",(0,n.jsxs)(t.ul,{children:["\n",(0,n.jsx)(t.li,{children:"The datum contains the keys of the two parties in the swap, and a description of what they are swapping."}),"\n",(0,n.jsx)(t.li,{children:"The redeemer is unused."}),"\n",(0,n.jsx)(t.li,{children:"The context contains a representation of the transaction."}),"\n"]}),"\n",(0,n.jsx)(t.h3,{id:"logic-of-the-validator-script",children:"Logic of the validator script"}),"\n",(0,n.jsx)(t.p,{children:"The logic of the validator script, then, is as follows:"}),"\n",(0,n.jsxs)(t.ul,{children:["\n",(0,n.jsx)(t.li,{children:"Does the transaction make a payment from the second party to the first party, containing the value that they are supposed to send?"}),"\n",(0,n.jsx)(t.li,{children:"If so, then they may spend this output and send it where they want (or we could insist that they send it to their key, but we might as well let them do what they like with it)."}),"\n"]}),"\n",(0,n.jsx)(t.h2,{id:"different-kinds-of-scripts",children:"Different kinds of scripts"}),"\n",(0,n.jsx)(t.p,{children:"The Cardano ledger currently has a few different kinds of validator scripts:"}),"\n",(0,n.jsxs)(t.ul,{children:["\n",(0,n.jsx)(t.li,{children:'The "simple" script language (introduced in the Allegra hard fork), which allows basic checks such as time locks'}),"\n",(0,n.jsxs)(t.li,{children:["Various Plutus language versions (see ",(0,n.jsx)(t.a,{href:"/docs/essential-concepts/language-versions",children:"Plutus language versions"}),")"]}),"\n"]}),"\n",(0,n.jsx)(t.h2,{id:"further-reading",children:"Further reading"}),"\n",(0,n.jsxs)(t.p,{children:["See ",(0,n.jsx)(t.a,{href:"https://www.essentialcardano.io/article/the-eutxo-handbook",children:"The EUTXO Handbook, A deep dive into Cardano's accounting model"}),"."]}),"\n",(0,n.jsx)(t.p,{children:"For more help on how to actually implement interesting logic using the EUTXO model and scripts, see:"}),"\n",(0,n.jsxs)(t.ul,{children:["\n",(0,n.jsx)(t.li,{children:(0,n.jsx)(t.a,{href:"../category/using-plutus-tx",children:"Using Plutus Tx"})}),"\n",(0,n.jsx)(t.li,{children:(0,n.jsx)(t.a,{href:"../category/working-with-scripts",children:"Working with scripts"})}),"\n"]})]})}function h(e={}){const{wrapper:t}={...(0,i.R)(),...e.components};return t?(0,n.jsx)(t,{...e,children:(0,n.jsx)(c,{...e})}):c(e)}},8453:(e,t,s)=>{s.d(t,{R:()=>r,x:()=>o});var n=s(6540);const i={},a=n.createContext(i);function r(e){const t=n.useContext(a);return n.useMemo((function(){return"function"==typeof e?e(t):{...t,...e}}),[t,e])}function o(e){let t;return t=e.disableParentContext?"function"==typeof e.components?e.components(i):e.components||i:r(e.components),n.createElement(a.Provider,{value:t},e.children)}}}]);