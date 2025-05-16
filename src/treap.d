alias Treap (T) = InternalTreap!(T, false, false, false).Treap;
alias Treap (T, alias op, alias e) = InternalTreap!(T, true, op, e).Treap;

template InternalTreap (T, bool ENABLE_MONOID_PRODUCT, alias op, alias e)
    if (!ENABLE_MONOID_PRODUCT
        || (__traits(compiles, op(T.init, T.init))
            && is(typeof(op(T.init, T.init)) == T)
            && __traits(compiles, e())
            && is(typeof(e()) == T)))
{
    private struct TreapNode {
        int size;
        uint priority;
        T value;
        static if (ENABLE_MONOID_PRODUCT) {
            T prod;
        }

        TreapNode* parent;
        TreapNode*[2] child;

        this (T _value, uint _priority, TreapNode* _parent) {
            size = 1;
            priority = _priority;
            value = _value;
            static if (ENABLE_MONOID_PRODUCT) {
                prod = _value;
            }
            parent = _parent;
        }

        void aggregation () {
            size = 1;
            static if (ENABLE_MONOID_PRODUCT) {
                prod = value;
            }

            if (child[0] !is null) {
                size += child[0].size;
                static if (ENABLE_MONOID_PRODUCT) {
                    prod = op(child[0].prod, prod);
                }
            }
            if (child[1] !is null) {
                size += child[1].size;
                static if (ENABLE_MONOID_PRODUCT) {
                    prod = op(prod, child[1].prod);
                }
            }
        }
        void rotateLeft () {
            TreapNode* rch = child[1];
            // 親の子リンク
            if (parent !is null) {
                if (parent.child[0] == &this) {
                    parent.child[0] = rch;
                }
                else {
                    parent.child[1] = rch;
                }
            }

            rch.parent = parent;
            parent = rch;
            child[1] = rch.child[0];
            // 子の親リンク
            if (rch.child[0] !is null) {
                rch.child[0].parent = &this;
            }
            rch.child[0] = &this;
        }
        void rotateRight () {
            TreapNode* lch = child[0];
            // 親の子リンク
            if (parent !is null) {
                if (parent.child[0] == &this) {
                    parent.child[0] = lch;
                }
                else {
                    parent.child[1] = lch;
                }
            }

            lch.parent = parent;
            parent = lch;
            child[0] = lch.child[1];
            // 子の親リンク
            if (lch.child[1] !is null) {
                lch.child[1].parent = &this;
            }
            lch.child[1] = &this;
        }
    }

    private int implicitKeyOf (const TreapNode* n) {
        pragma(inline);
        assert(n !is null);
        if (n.child[0] is null) {
            return 1;
        }
        return n.child[0].size + 1;
    }

    class Treap {
        import std.exception: enforce;
        import std.random;
        import std.range.primitives: isInputRange;
        import std.range: iota, enumerate;
        import std.algorithm: map;
        import std.traits: isImplicitlyConvertible, ForeachType;
        import std.conv: to;
        private {
            size_t lengthPayload;
            TreapNode* root;
            Xorshift gen;
        }

        this (size_t N) {
            this(iota(N).map!(a => T.init));
        }
        this (Irange) (Irange r)
            if (isInputRange!(Irange) && isImplicitlyConvertible!(ForeachType!(Irange), T))
        {
            gen.seed(unpredictableSeed());
            foreach (i, value; r.enumerate(0)) {
                insert(i, value);
            }
        }

        private uint randomValue () {
            uint ret = gen.front();
            gen.popFront();
            return ret;
        }

        void insert (size_t index, T value) {
            enforce(index <= length());
            lengthPayload++;

            if (root is null) {
                root = new TreapNode(value, randomValue(), null);
                return;
            }

            // nullの直前まで降りる
            TreapNode* cur = root;
            int direction = -1;
            while (true) {
                int key = implicitKeyOf(cur);
                if (index < key) {
                    direction = 0;
                }
                else {
                    index -= key;
                    direction = 1;
                }

                if (cur.child[direction] is null) {
                    break;
                }
                cur = cur.child[direction];
            }

            // ノードを作成
            cur.child[direction] = new TreapNode(value, randomValue(), cur);
            cur = cur.child[direction];

            // 優先度条件を満たすまで回転
            while (cur.parent !is null && cur.parent.priority < cur.priority) {
                if (cur.parent.child[0] == cur) {
                    cur.parent.rotateRight();
                    cur.child[1].aggregation();
                }
                else {
                    cur.parent.rotateLeft();
                    cur.child[0].aggregation();
                }
                cur.aggregation();
            }

            // 集約を親に伝搬
            while (true) {
                if (cur.parent is null) {
                    break;
                }
                cur = cur.parent;
                cur.aggregation();
            }

            root = cur;
        }

        void remove (size_t index) {
            enforce(index < length());
            lengthPayload--;

            if (length() == 0) {
                root = null;
                return;
            }

            // 該当要素を検索
            TreapNode* cur = find(index);

            // 葉になるまで回転
            while (true) {
                if (cur.child[0] is null && cur.child[1] is null) {
                    break;
                }
                uint lp = 0;
                if (cur.child[0] !is null) {
                    lp = cur.child[0].priority;
                }
                uint rp = 0;
                if (cur.child[1] !is null) {
                    rp = cur.child[1].priority;
                }

                if (lp < rp) {
                    cur.rotateLeft();
                }
                else {
                    cur.rotateRight();
                }
            }

            // リンクの切断
            if (cur.parent.child[0] == cur) {
                cur.parent.child[0] = null;
            }
            if (cur.parent.child[1] == cur) {
                cur.parent.child[1] = null;
            }

            // 集約を親に伝搬
            cur = cur.parent;
            while (true) {
                cur.aggregation();
                if (cur.parent is null) {
                    break;
                }
                cur = cur.parent;
            }

            root = cur;
        }

        static if (ENABLE_MONOID_PRODUCT) {
            T prod (const size_t l, const size_t r) const {
                enforce(0 <= l && l < length());
                enforce(0 <= r && r <= length());
                enforce(l <= r);

                T internal_prod (const TreapNode* cur, const size_t cur_l, const size_t cur_r) const {
                    if (cur is null) {
                        return e();
                    }
                    // 共通部分なし
                    if (r <= cur_l || cur_r <= l) {
                        return e();
                    }
                    // 包含されている
                    if (l <= cur_l && cur_r <= r) {
                        return cur.prod;
                    }

                    // 現在位置
                    int key = implicitKeyOf(cur) - 1;

                    // 左区間
                    T ret = internal_prod(cur.child[0], cur_l, cur_l + key);
                    if (l <= cur_l + key && cur_l + key < r) {
                        ret = op(ret, cur.value);
                    }
                    // 右区間
                    ret = op(ret, internal_prod(cur.child[1], cur_l + key + 1, cur_r));

                    return ret;
                }

                return internal_prod(root, 0, length());
            }
        }

        private TreapNode* find (size_t index) {
            enforce(index < length());

            TreapNode* cur = root;

            while (true) {
                int key = implicitKeyOf(cur);
                if (index + 1 == key) {
                    break;
                }
                if (index < key) {
                    cur = cur.child[0];
                }
                else {
                    cur = cur.child[1];
                    index -= key;
                }
            }
            return cur;
        }

        // indexアクセス
        T opIndex (size_t i) {
            enforce(0 <= i && i < length());
            return find(i).value;
        }

        // indexアクセス + 代入
        T opIndexAssign (T value, size_t i) {
            enforce(0 <= i && i < length());
            TreapNode* cur = find(i);
            cur.value = value;
            while (cur !is null) {
                cur.aggregation();
                cur = cur.parent;
            }
            return value;
        }

        // indexアクセス + 代入演算子
        T opIndexOpAssign (string op) (T value, size_t i) {
            enforce(0 <= i && i < length());

            TreapNode* cur = find(i);
            mixin("cur.value" ~ op ~ "= value;");
            T ret = cur.value;
            while (cur !is null) {
                cur.aggregation();
                cur = cur.parent;
            }
            return ret;
        }

        // indexアクセス + 単項演算子
        T opIndexUnary (string op) (size_t i) {
            enforce(0 <= i && i < length());
            return mixin(op ~ "find(i).value;");
        }

        // $のindex変換
        size_t opDollar () const {
            return length();
        }

        size_t length () const {
            return lengthPayload;
        }

        override string toString () {
            string ret = "[";
            foreach (i; 0 .. length()) {
                ret ~= find(i).value.to!string;
                if (i < length() - 1) {
                    ret ~= ", ";
                }
            }
            ret ~= "]";
            return ret;
        }
    }
}

import std;

void main () {
    int N, Q;
    readln.read(N, Q);

    auto A = readln.split.to!(int[]);
    auto treap = new Treap!(int, (int a, int b) => a ^ b, () => 0)(A);
    auto ans = new int[](0);

    foreach (i; 0 .. Q) {
        int T, X, Y;
        readln.read(T, X, Y);

        if (T == 1) {
            treap[X - 1] ^= Y;
        }
        if (T == 2) {
            ans ~= treap.prod(X - 1, Y);
        }
    }

    writefln("%(%s\n%)", ans);
}

void read (T...) (string S, ref T args) {
    import std.conv : to;
    import std.array : split;
    auto buf = S.split;
    foreach (i, ref arg; args) {
        arg = buf[i].to!(typeof(arg));
    }
}
