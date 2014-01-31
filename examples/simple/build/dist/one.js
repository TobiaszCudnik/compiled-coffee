var __extends = this.__extends || function (d, b) {
    for (var p in b) if (b.hasOwnProperty(p)) d[p] = b[p];
    function __() { this.constructor = d; }
    __.prototype = b.prototype;
    d.prototype = new __();
};
var One = (function () {
    function One(string_attr, number_attr) {
        this.string_attr = "abc";
        this.number_attr = null;
        this.priv_attr = null;
        this.string_attr = string_attr;
        this.number_attr = number_attr;
        this.method();
    }
    One.prototype.method = function () {
        return this.string_attr + this.number_attr;
    };
    return One;
})();
exports.One = One;

var Two = (function (_super) {
    __extends(Two, _super);
    function Two() {
        _super.apply(this, arguments);
    }
    Two.prototype.method = function (str) {
        return this.string_attr + str + this.number_attr;
    };
    return Two;
})(One);
exports.Two = Two;

exports.one = new One("foo", 123);
exports.two = new Two("foo", 123);

exports.one.method().replace(/foo/, "bar");
(exports.two.method("bar")).replace(/bar/, "foo");
//# sourceMappingURL=one.js.map