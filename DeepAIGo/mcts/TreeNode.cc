#include "TreeNode.h"

namespace DeepAIGo
{
    TreeNode::TreeNode(Point action, float P, TreeNode::Ptr parent)
        : action_(action), P_(P), parent_(parent), is_expanded_(false)
    {
        W_ = 0;
        N_ = 0;
    }

    TreeNode::Ptr TreeNode::Select()
    {
        size_t total_games = 0;
        for (auto& n : children_)
            total_games += n->GetVisits();

        size_t max_idx = 0;
        float max_value = -9999.f;

        for (size_t i = 0; i < children_.size(); ++i)
        {
            float q = (GetVisits()) ? W_.load() / GetVisits() : 0;
            float u = TreeNode::puct * children_[i]->P_.load() * std::sqrt(total_games) / (1.f + GetVisits());

            if (q + u > max_value)
            {
                max_value = q + u;
                max_idx = i;
            }
        }

        return children_[max_idx];
    }

    void TreeNode::Expand(const std::vector<ActionProb>& probs)
    {
        std::lock_guard<std::mutex> lock(mutex_);
        if (is_expanded_) return;

        is_expanded_ = true;

        for (auto& p : probs)
        {
            children_.emplace_back(
                std::make_shared<TreeNode>(std::get<0>(p), std::get<1>(p), shared_from_this()));
        }
    }

    const Point& TreeNode::GetAction() const
    {
        return action_;
    }

    void TreeNode::SetParent(TreeNode::Ptr parent)
    {
        parent_ = parent;
    }

    TreeNode::Ptr TreeNode::GetParent()
    {
        return parent_;
    }

    std::deque<TreeNode::Ptr>& TreeNode::GetChildren()
    {
        return children_;
    }

    bool TreeNode::IsRoot() const
    {
        return parent_ == nullptr;
    }

    bool TreeNode::HasChild() const
    {
        return children_.size() > 0;
    }

    int TreeNode::GetVisits() const
    {
        return N_.load();
    }

    float TreeNode::GetValue() const
    {
        size_t total_games = 0;
        for (auto& n : children_)
            total_games += n->GetVisits();

        float q = (GetVisits()) ? W_.load() / GetVisits() : 0;
        float u = TreeNode::puct * P_.load() * std::sqrt(total_games) / (1.f + GetVisits());

        return q + u;
    }

    void TreeNode::Update(int w, bool own)
    {
        if (parent_ != nullptr)
            parent_->Update(w, !own);

        update(w, own);
    }

    void TreeNode::update(int w, bool own)
    {
        atomic_fetch_add(&N_, 1);
        atomic_fetch_add(&W_, w * (own ? 1 : -1));
        atomic_fetch_sub(&W_, TreeNode::Vl);
    }
}