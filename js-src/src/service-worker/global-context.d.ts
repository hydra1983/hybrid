declare function __promiseCallback(callbackIndex: number, error?: Error, response?: any): void;
declare function __execDatabaseQuery(nativeDbId:number, queries:string, readOnly:Boolean): string;
declare function __setGlobals(keys: [string]): void;
declare function __console(message:string): void;
declare function __createWebSQLConnection(name:string): number;

declare interface ConsoleMessage {
    level:string;
    text:string;
}

declare class ExtendableEvent extends Event {
    waitUntil(promise: Promise<any>): void
    resolve():Promise<any>
}

declare var hybrid: any;

declare var global: any;

declare module "websql/custom" {
    var _temp:any;
    module _temp {}
    export = _temp;
}