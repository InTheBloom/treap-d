template Treap (T) {
    private struct TreapNode {
        int size;
        uint priority;
        T value;
        TreapNode* parent;
        TreapNode*[2] child;

        this (T _value, uint _priority, TreapNode* _parent) {
            size = 1;
            priority = _priority;
            value = _value;
            parent = _parent;
        }

        void aggregation () {
            size = 1;
            if (child[0] !is null) {
                size += child[0].size;
            }
            if (child[1] !is null) {
                size += child[1].size;
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
        private:
            size_t lengthPayload;
            TreapNode* root;
            Xorshift gen;

        this (size_t N) {
            T[] A;
            this(A);
        }
        this (InputRange) (InputRange r) {
            gen.seed(unpredictableSeed());
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
            return find(i).value = value;
        }

        // スライス
        size_t[2] opSlice (size_t i, size_t j) {
            enforce(0 <= i && i < length());
            enforce(0 <= j && j <= length());
            enforce(i <= j);
            size_t[2] ret = [i, j];
            return ret;
        }

        // スライス + 代入（指定なし）
        void opIndexAssign (T value) {
            opIndexAssign(value, opSlice(0, length()));
        }

        // スライス + 代入
        void opIndexAssign (T value, size_t[2] slice) {
            foreach (i; slice[0] .. slice[1]) {
                opIndexAssign(value, i);
            }
        }

        // スライス + 代入演算子（指定なし）
        void opIndexOpAssign (string op) (T value) {
            opIndexOpAssign(value, opSlice(0, length()));
        }

        // スライス + 代入演算子
        void opIndexOpAssign (string op) (T value, size_t[2] slice) {
            import std.stdio;
            writeln(slice);
            foreach (i; slice[0] .. slice[1]) {
                opIndexOpAssign!(op)(value, i);
            }
        }

        // indexアクセス + 代入演算子
        T opIndexOpAssign (string op) (T value, size_t i) {
            enforce(0 <= i && i < length());
            return mixin("find(i).value" ~ op ~ "= value");
        }

        // indexアクセス + 単項演算子
        T opIndexUnary (string op) (size_t i) {
            enforce(0 <= i && i < length());
            return mixin(op ~ "find(i).value");
        }

        // $のindex変換
        size_t opDollar () const {
            return length();
        }

        private void debugDfs () {
            if (root is null) {
                return;
            }

            import std.stdio;
            stderr.writefln("root: %s", root.value);
            void dfs (TreapNode* r) {
                if (r.child[0] !is null) {
                    writefln("%s %s", r.value, r.child[0].value);
                    dfs(r.child[0]);
                }
                if (r.child[1] !is null) {
                    writefln("%s %s", r.value, r.child[1].value);
                    dfs(r.child[1]);
                }
            }
            dfs(root);
        }

        size_t length () const {
            return lengthPayload;
        }
    }
}

void main () {
    import std;

    auto A = new Treap!(int)(10);
    foreach (i; 0 .. 100) {
        A.insert(0, i);
    }
    A.debugDfs();

    A[99];
    ++A[99];
    --A[99];
    -A[99];
    ~A[99];
    A[0] += 1;
    A[0] /= 10;
    A[0 .. $] += 1;
    foreach (i; 0 .. 100) {
    }


    return;
}
