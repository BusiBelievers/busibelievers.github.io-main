window.BUSI_SUPABASE = { 
url: "https://pocdjxubtdxyqyntlxnt.supabase.co",
anonKey: "sb_publishable_6k8ZnNuxryYwqOPaYbGsnA__cxt_gzM",

isConfigured: function(){
return Boolean(this.url && this.anonKey && window.supabase);
},

createClient: function(){
if(!this.isConfigured()){
return null;
}
return window.supabase.createClient(this.url, this.anonKey);
}
};
