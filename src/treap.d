template Treap (T) {
    private struct TreapNode {
        int size;
        uint priority;
        T value;
        TreapNode* parent;
        TreapNode*[2] child;

        this (T _value, TreapNode* _parent) {
            size = 1;
            priority = randomValue();
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

    private uint randomValue () {
        pragma(inline);
        import std.random;
        static Xorshift gen;
        static bool init = false;
        if (init) {
            gen.popFront();
            return gen.front();
        }
        gen.seed(unpredictableSeed());
        init = true;

        return gen.front();
    }

    int implicitKeyOf (TreapNode* n) {
        pragma(inline);
        assert(n !is null);
        if (n.child[0] is null) {
            return 1;
        }
        return n.child[0].size + 1;
    }

    class Treap {
        private:
            size_t lengthPayload;
            TreapNode* root;

        this (size_t N) {
        }
        this (InputRange) (InputRange r) {
        }

        void insert (size_t index, T value) {
            if (root is null) {
                root = new TreapNode(value, null);
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
            cur.child[direction] = new TreapNode(value, cur);
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

            // 回転で根が変更
            if (cur.parent is null) {
                root = cur;
            }

            // 集約を親に伝搬
            cur = cur.parent;
            while (cur !is null) {
                cur.aggregation();
                cur = cur.parent;
            }
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
        A.insert(i, i);
    }

    foreach (i; 0 .. 100) {
        A.remove(i);
    }

    //A.debugDfs();
    return;
}
